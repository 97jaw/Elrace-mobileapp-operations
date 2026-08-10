/**
 * Shared Whisper helper for My Notes audio.
 * Used by Storage upload hook (only when requested) and processNoteAi on-demand.
 */
const { FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const OpenAI = require("openai");
const os = require("os");
const path = require("path");
const fs = require("fs");

/**
 * Transcribe a note's audio via Whisper and write recording.transcript.
 * @returns {Promise<string>} transcript text
 */
async function transcribeNoteRecording({
  noteRef,
  apiKey,
  storagePath,
  bucketName,
  languageMeta = "auto",
}) {
  const snap = await noteRef.get();
  if (!snap.exists) {
    throw new Error("Note not found");
  }
  const data = snap.data() || {};
  const recording = data.recording || {};
  const existingTranscript =
    typeof recording.transcript === "string" ? recording.transcript.trim() : "";
  if (existingTranscript) {
    return existingTranscript;
  }

  let filePath = storagePath || recording.storagePath || null;
  if (!filePath) {
    // users/{uid}/notes/{noteId}
    const parts = noteRef.path.split("/");
    if (parts.length >= 4 && parts[0] === "users" && parts[2] === "notes") {
      filePath = `chat_media/notes/${parts[1]}/${parts[3]}/audio.m4a`;
    }
  }
  if (!filePath) {
    throw new Error("No audio storage path on note");
  }

  await noteRef.update({
    "recording.status": "processing",
    updatedAt: FieldValue.serverTimestamp(),
  });

  let tempFile;
  try {
    const bucket = bucketName
      ? getStorage().bucket(bucketName)
      : getStorage().bucket();
    tempFile = path.join(os.tmpdir(), `note_od_${Date.now()}.m4a`);
    await bucket.file(filePath).download({ destination: tempFile });

    const openai = new OpenAI({ apiKey });
    const createArgs = {
      file: fs.createReadStream(tempFile),
      model: "whisper-1",
    };
    const lang = languageMeta || recording.language || "auto";
    if (lang === "en" || lang === "ar") {
      createArgs.language = lang;
    }

    const transcription = await openai.audio.transcriptions.create(createArgs);
    const text = (transcription.text || "").trim();

    const updates = {
      "recording.transcript": text,
      "recording.status": "done",
      "recording.language": lang,
      "recording.storagePath": filePath,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (recording.audioUrl) {
      updates["recording.audioUrl"] = recording.audioUrl;
    }
    await noteRef.update(updates);
    return text;
  } catch (err) {
    try {
      await noteRef.update({
        "recording.status": "error",
        updatedAt: FieldValue.serverTimestamp(),
      });
    } catch (_) {}
    throw err;
  } finally {
    if (tempFile) {
      try {
        fs.unlinkSync(tempFile);
      } catch (_) {}
    }
  }
}

exports.transcribeNoteRecording = transcribeNoteRecording;
