/**
 * My Notes — Whisper transcription when audio is uploaded to Storage.
 *
 * Path: chat_media/notes/{uid}/{noteId}/audio.m4a
 * Requires secret: OPENAI_API_KEY
 *
 * Always transcribes on upload unless a transcript is already done.
 */
const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { defineSecret, defineString } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { transcribeNoteRecording } = require("./notes_whisper");

const openaiApiKey = defineSecret("OPENAI_API_KEY");
const storageBucket = defineString("ELRACE_STORAGE_BUCKET", {
  default: "elrace-new.firebasestorage.app",
});

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Wait until the note doc exists (client creates it before upload). */
async function waitForNoteDoc(noteRef, { attempts = 16, delayMs = 400 } = {}) {
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

/** Transcribe every new upload unless transcript already exists / done. */
function shouldTranscribeOnUpload(data) {
  const recording = (data && data.recording) || {};
  const status = recording.status || "idle";
  const transcript =
    typeof recording.transcript === "string" ? recording.transcript.trim() : "";
  if (transcript) return false;
  if (status === "done") return false;
  return true;
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
      console.log("[NotesTranscribe] Skip — transcript already present", {
        noteId,
        status: (existing.recording && existing.recording.status) || "idle",
      });
      return;
    }

    const languageMeta =
      (object.metadata && object.metadata.language) ||
      (existing.recording && existing.recording.language) ||
      "auto";

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
    bucket: storageBucket,
    secrets: [openaiApiKey],
    memory: "1GiB",
    timeoutSeconds: 300,
  },
  handleNotesAudioUpload,
);
