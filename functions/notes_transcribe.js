/**
 * My Notes — Whisper transcription when audio is uploaded to Storage.
 *
 * Path: chat_media/notes/{uid}/{noteId}/audio.m4a
 * Requires secret: OPENAI_API_KEY
 *
 * On-demand only: skips unless the note requested transcription
 * (recording.status === 'pending' or transcribeRequested / AI mode that needs it).
 */
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { transcribeNoteRecording } = require("./notes_whisper");

const openaiApiKey = defineSecret("OPENAI_API_KEY");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Wait until the note doc exists (client creates it before upload). */
async function waitForNoteDoc(noteRef, { attempts = 12, delayMs = 1000 } = {}) {
  for (let i = 0; i < attempts; i++) {
    const snap = await noteRef.get();
    if (snap.exists) return snap;
    console.log("[NotesTranscribe] Waiting for note doc…", {
      attempt: i + 1,
      attempts,
    });
    await sleep(delayMs);
  }
  return null;
}

function shouldTranscribeOnUpload(data) {
  const recording = (data && data.recording) || {};
  const status = recording.status || "idle";
  const requested = recording.transcribeRequested === true;
  const aiMode = data.aiMode || "none";
  // Whisper ONLY when the user explicitly asked to transcribe — never for
  // summarize / bullets / save-only.
  if (requested) return true;
  if (status === "pending" && aiMode === "transcribe") return true;
  if (aiMode === "transcribe" && status !== "done" && status !== "error") {
    return true;
  }
  return false;
}

async function handleNotesAudioUpload(event) {
  const object = event.data;
  const filePath = object.name;
  if (!filePath) return;

  const match =
    filePath.match(
      /^chat_media\/notes\/([^/]+)\/([^/]+)\/audio\.(m4a|mp3|wav|ogg|webm)$/i,
    ) ||
    filePath.match(
      /^users\/([^/]+)\/notes\/([^/]+)\/audio\.(m4a|mp3|wav|ogg|webm)$/i,
    );
  if (!match) {
    return;
  }

  const [, userId, noteId] = match;
  console.log("[NotesTranscribe] Processing", { filePath, userId, noteId });

  const db = getFirestore();
  const noteRef = db
    .collection("users")
    .doc(userId)
    .collection("notes")
    .doc(noteId);

  try {
    const existingSnap = await waitForNoteDoc(noteRef);
    if (!existingSnap) {
      throw new Error(
        `Note document not found after wait: users/${userId}/notes/${noteId}`,
      );
    }

    const existing = existingSnap.data() || {};
    if (!shouldTranscribeOnUpload(existing)) {
      console.log("[NotesTranscribe] Skip — transcription not requested", {
        noteId,
        status: (existing.recording && existing.recording.status) || "idle",
        aiMode: existing.aiMode || "none",
      });
      // Ensure idle status so UI does not show a spinner.
      const recStatus =
        (existing.recording && existing.recording.status) || "idle";
      if (recStatus === "pending" || recStatus === "processing") {
        await noteRef.update({
          "recording.status": "idle",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
      return;
    }

    const languageMeta =
      (object.metadata && object.metadata.language) || "auto";

    const text = await transcribeNoteRecording({
      noteRef,
      apiKey: openaiApiKey.value(),
      storagePath: filePath,
      bucketName: object.bucket,
      languageMeta,
    });

    console.log("[NotesTranscribe] Done", { noteId, chars: text.length });
    // No auto summarize/bullets here — those are separate on-demand AI actions.
  } catch (err) {
    console.error("[NotesTranscribe] Failed", err);
    try {
      await noteRef.update({
        "recording.status": "error",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}

exports.onNotesAudioUploaded = onObjectFinalized(
  {
    region: "us-central1",
    secrets: [openaiApiKey],
    memory: "1GiB",
    timeoutSeconds: 300,
  },
  handleNotesAudioUpload,
);
