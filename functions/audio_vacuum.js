/**
 * Hourly vacuum: delete audio older than 24h from Notes, Chat, and Task comments.
 * Notes keep the Firestore doc; title is rewritten from transcript/summary.
 */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");

const TWENTY_FOUR_HOURS_MS = 24 * 60 * 60 * 1000;

function truncateTitle(text, max = 60) {
  const t = (text || "").replace(/\s+/g, " ").trim();
  if (!t) return "Note (audio expired)";
  if (t.length <= max) return t;
  return `${t.slice(0, max - 1).trim()}…`;
}

function titleAfterAudioPurge(data) {
  const transcript =
    data.recording && typeof data.recording.transcript === "string"
      ? data.recording.transcript.trim()
      : "";
  if (transcript) return truncateTitle(transcript);

  const summary =
    typeof data.aiSummary === "string" ? data.aiSummary.trim() : "";
  if (summary) return truncateTitle(summary);

  const bullets =
    typeof data.aiBulletPoints === "string" ? data.aiBulletPoints.trim() : "";
  if (bullets) {
    const first = bullets
      .split("\n")
      .map((l) => l.replace(/^[-*•]\s*/, "").trim())
      .find(Boolean);
    if (first) return truncateTitle(first);
  }

  const existing = typeof data.title === "string" ? data.title.trim() : "";
  if (existing && !/^Audio note\b/i.test(existing)) {
    return existing;
  }
  return "Note (audio expired)";
}

async function safeDeleteStorage(bucket, path) {
  if (!path) return;
  try {
    await bucket.file(path).delete({ ignoreNotFound: true });
    console.log("[AudioVacuum] Deleted storage", path);
  } catch (e) {
    console.log("[AudioVacuum] Storage delete skip", path, e.message);
  }
}

function pathFromNotesRecording(data, ownerId, noteId) {
  const rec = data.recording || {};
  if (rec.storagePath) return rec.storagePath;
  if (ownerId && noteId) {
    return `chat_media/notes/${ownerId}/${noteId}/audio.m4a`;
  }
  return null;
}

function asDate(value) {
  if (!value) return null;
  if (typeof value.toDate === "function") return value.toDate();
  if (typeof value === "string") return new Date(value);
  if (value instanceof Date) return value;
  return null;
}

async function purgeNotesAudio(db, bucket, cutoff) {
  let purged = 0;
  const usersSnap = await db.collection("users").select().get();

  for (const userDoc of usersSnap.docs) {
    const notesSnap = await userDoc.ref
      .collection("notes")
      .where("noteType", "==", "audio")
      .get();

    for (const noteDoc of notesSnap.docs) {
      const data = noteDoc.data() || {};
      const created = asDate(data.createdAt);
      if (!created || created.getTime() > cutoff.getTime()) continue;

      const rec = data.recording || {};
      if (!rec.audioUrl && !rec.storagePath) continue;

      const path = pathFromNotesRecording(data, userDoc.id, noteDoc.id);
      await safeDeleteStorage(bucket, path);

      const newTitle = titleAfterAudioPurge(data);
      await noteDoc.ref.update({
        title: newTitle,
        "recording.audioUrl": "",
        "recording.storagePath": FieldValue.delete(),
        "recording.purgedAt": FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      purged += 1;
    }
  }
  return purged;
}

async function purgeChatVoice(db, bucket, cutoffTs) {
  let purged = 0;
  const chatsSnap = await db.collection("chats").select().get();

  for (const chatDoc of chatsSnap.docs) {
    let docs = [];
    try {
      const messagesSnap = await chatDoc.ref
        .collection("messages")
        .where("type", "==", "audio")
        .where("created_at", "<", cutoffTs)
        .get();
      docs = messagesSnap.docs;
    } catch (_) {
      const all = await chatDoc.ref
        .collection("messages")
        .where("type", "==", "audio")
        .get();
      docs = all.docs.filter((d) => {
        const dt = asDate(d.data().created_at);
        return dt && dt.getTime() < cutoffTs.toMillis();
      });
    }

    for (const msgDoc of docs) {
      const data = msgDoc.data() || {};
      await safeDeleteStorage(bucket, data.media_path);
      await msgDoc.ref.update({
        media_url: "",
        media_path: FieldValue.delete(),
        text: "🎵 Voice message expired",
        audio_purged_at: FieldValue.serverTimestamp(),
      });
      purged += 1;
    }
  }
  return purged;
}

async function purgeTaskVoiceComments(db, bucket, cutoff) {
  let purged = 0;
  const usersSnap = await db.collection("users").select().get();

  for (const userDoc of usersSnap.docs) {
    const todosSnap = await userDoc.ref.collection("todos").select().get();
    for (const todoDoc of todosSnap.docs) {
      let commentsSnap;
      try {
        commentsSnap = await todoDoc.ref
          .collection("comments")
          .where("type", "==", "voice")
          .get();
      } catch (_) {
        continue;
      }

      for (const commentDoc of commentsSnap.docs) {
        const data = commentDoc.data() || {};
        const created = asDate(data.created_at);
        if (!created || created.getTime() > cutoff.getTime()) continue;
        if (!data.audio_url && !data.audio_path) continue;

        if (data.audio_path) {
          await safeDeleteStorage(bucket, data.audio_path);
        } else {
          // Best-effort: purge aged files under this task's voice_comments prefix.
          try {
            const [files] = await bucket.getFiles({
              prefix: `voice_comments/${todoDoc.id}/`,
              maxResults: 50,
            });
            for (const f of files) {
              const [meta] = await f.getMetadata();
              const updated = new Date(meta.updated || meta.timeCreated);
              if (updated.getTime() <= cutoff.getTime()) {
                await safeDeleteStorage(bucket, f.name);
              }
            }
          } catch (_) {
            // ignore
          }
        }

        await commentDoc.ref.update({
          audio_url: "",
          content: "🎤 Voice comment expired",
          audio_purged_at: FieldValue.serverTimestamp(),
        });
        purged += 1;
      }
    }
  }
  return purged;
}

exports.cleanupExpiredAudio = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "UTC",
    region: "us-central1",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const db = getFirestore();
    const bucket = getStorage().bucket();
    const cutoff = new Date(Date.now() - TWENTY_FOUR_HOURS_MS);
    const cutoffTs = Timestamp.fromDate(cutoff);

    console.log("[AudioVacuum] Start", { cutoff: cutoff.toISOString() });

    const notes = await purgeNotesAudio(db, bucket, cutoff);
    const chat = await purgeChatVoice(db, bucket, cutoffTs);
    const tasks = await purgeTaskVoiceComments(db, bucket, cutoff);

    console.log("[AudioVacuum] Done", { notes, chat, tasks });
  },
);
