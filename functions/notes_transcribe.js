/**
 * My Notes — Whisper transcription when audio is uploaded to Storage.
 *
 * Path: chat_media/notes/{uid}/{noteId}/audio.m4a
 * Requires secret: OPENAI_API_KEY
 */
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const OpenAI = require("openai");
const os = require("os");
const path = require("path");
const fs = require("fs");

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

  let tempFile;

  try {
    const existingSnap = await waitForNoteDoc(noteRef);
    if (!existingSnap) {
      throw new Error(
        `Note document not found after wait: users/${userId}/notes/${noteId}`,
      );
    }

    await noteRef.update({
      "recording.status": "processing",
      updatedAt: FieldValue.serverTimestamp(),
    });

    const bucket = getStorage().bucket(object.bucket);
    tempFile = path.join(os.tmpdir(), `note_${noteId}_${Date.now()}.m4a`);
    await bucket.file(filePath).download({ destination: tempFile });

    const languageMeta =
      (object.metadata && object.metadata.language) || "auto";
    const openai = new OpenAI({ apiKey: openaiApiKey.value() });

    const createArgs = {
      file: fs.createReadStream(tempFile),
      model: "whisper-1",
    };
    if (languageMeta === "en" || languageMeta === "ar") {
      createArgs.language = languageMeta;
    }

    const transcription = await openai.audio.transcriptions.create(createArgs);
    const text = (transcription.text || "").trim();

    const noteSnap = await noteRef.get();
    const existing = noteSnap.exists ? noteSnap.data() || {} : {};
    const existingContent =
      typeof existing.content === "string" ? existing.content.trim() : "";
    const existingRecording = existing.recording || {};

    const updates = {
      "recording.transcript": text,
      "recording.status": "done",
      "recording.language": languageMeta,
      updatedAt: FieldValue.serverTimestamp(),
    };
    // Keep audioUrl if already set by the client.
    if (existingRecording.audioUrl) {
      updates["recording.audioUrl"] = existingRecording.audioUrl;
    }
    if (!existingContent) {
      updates.content = text;
    }

    await noteRef.update(updates);

    console.log("[NotesTranscribe] Done", { noteId, chars: text.length });
  } catch (err) {
    console.error("[NotesTranscribe] Failed", err);
    try {
      await noteRef.update({
        "recording.status": "error",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  } finally {
    if (tempFile) {
      try {
        fs.unlinkSync(tempFile);
      } catch (_) {}
    }
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
