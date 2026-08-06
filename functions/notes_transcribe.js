/**
 * My Notes — Whisper transcription when audio is uploaded to Storage.
 *
 * Path: users/{uid}/notes/{noteId}/audio.m4a
 * Requires secret: OPENAI_API_KEY
 *   firebase functions:secrets:set OPENAI_API_KEY
 * Deploy:
 *   firebase deploy --only functions:onNotesAudioUploaded --project elrace-new
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

async function handleNotesAudioUpload(event) {
  const object = event.data;
  const filePath = object.name;
  if (!filePath) return;

  // chat_media/notes/{uid}/{noteId}/audio.m4a
  // (also supports users/{uid}/notes/{noteId}/audio.m4a)
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
  const noteRef = db.collection("users").doc(userId).collection("notes").doc(noteId);

  try {
    await noteRef.update({
      "recording.status": "processing",
      updatedAt: FieldValue.serverTimestamp(),
    });

    const bucket = getStorage().bucket(object.bucket);
    const tempFile = path.join(os.tmpdir(), `note_${noteId}_${Date.now()}.m4a`);
    await bucket.file(filePath).download({ destination: tempFile });

    const languageMeta = (object.metadata && object.metadata.language) || "auto";
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

    const updates = {
      "recording.transcript": text,
      "recording.status": "done",
      "recording.language": languageMeta,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (!existingContent) {
      updates.content = text;
    }

    await noteRef.update(updates);

    try {
      fs.unlinkSync(tempFile);
    } catch (_) {}

    console.log("[NotesTranscribe] Done", { noteId, chars: text.length });
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
    region: "me-central-1",
    secrets: [openaiApiKey],
    memory: "1GiB",
    timeoutSeconds: 300,
  },
  handleNotesAudioUpload,
);
