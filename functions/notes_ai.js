/**
 * My Notes — GPT processing (summarize, bullets, actions, tags, translate).
 * Whisper runs on Storage upload (auto). Callable mode "transcribe" only waits
 * for / returns an existing transcript (backward compatible).
 * Callable: processNoteAi
 * Also exported: runNoteAiOnDoc for Whisper post-hook.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const OpenAI = require("openai");
const crypto = require("crypto");
const { transcribeNoteRecording } = require("./notes_whisper");

const openaiApiKey = defineSecret("OPENAI_API_KEY");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForTranscript(noteRef, { attempts = 8, delayMs = 1500 } = {}) {
  for (let i = 0; i < attempts; i++) {
    const snap = await noteRef.get();
    if (!snap.exists) {
      await sleep(delayMs);
      continue;
    }
    const data = snap.data() || {};
    const transcript = (data.recording && data.recording.transcript) || "";
    const status = (data.recording && data.recording.status) || "";
    if (transcript.trim()) return { snap, data, transcript: transcript.trim() };
    if (status === "error") {
      throw new HttpsError("failed-precondition", "Transcription failed");
    }
    await sleep(delayMs);
  }
  return null;
}

function sourceTextFromNote(data, mode) {
  const transcript =
    data.recording && typeof data.recording.transcript === "string"
      ? data.recording.transcript.trim()
      : "";
  const summary =
    typeof data.aiSummary === "string" ? data.aiSummary.trim() : "";
  const content = typeof data.content === "string" ? data.content.trim() : "";

  // Build on summary when present (bullets / actions under the summary).
  if ((mode === "bullets" || mode === "actions") && summary) {
    return summary;
  }
  if (transcript) return transcript;
  if (summary) return summary;
  return content;
}

async function ensureTranscriptIfNeeded({ noteRef, data, apiKey, mode }) {
  let sourceText = sourceTextFromNote(data, mode);
  if (sourceText) return sourceText;

  // Summarize / bullets / etc. never start Whisper — upload CF owns that.
  if (mode !== "transcribe") {
    // If upload CF is still running, wait briefly so summarize can proceed.
    if (data.recording) {
      const status = (data.recording && data.recording.status) || "idle";
      if (status === "pending" || status === "processing") {
        const waited = await waitForTranscript(noteRef);
        if (waited && waited.transcript) return waited.transcript;
      }
    }
    return "";
  }

  // Legacy mode "transcribe": wait for auto-upload Whisper; do not start a
  // second job unless nothing is in flight and audio exists.
  if (!data.recording) {
    return "";
  }

  const status = (data.recording && data.recording.status) || "idle";
  if (status === "pending" || status === "processing") {
    const waited = await waitForTranscript(noteRef);
    if (waited && waited.transcript) return waited.transcript;
  }

  if (status === "done") {
    return sourceTextFromNote((await noteRef.get()).data() || {}, mode) || "";
  }

  return transcribeNoteRecording({
    noteRef,
    apiKey,
    storagePath: data.recording && data.recording.storagePath,
    languageMeta: (data.recording && data.recording.language) || "auto",
  });
}

async function runGpt({ openai, mode, sourceText, targetLanguage }) {
  let system;
  let user = sourceText;

  switch (mode) {
    case "transcribe":
      return sourceText;
    case "summarize":
      system =
        "You are a professional note-taking assistant. Write a clear executive summary in 3-5 sentences. Prefer decisions, owners, deadlines, risks, and next steps when they appear in the source. Do not invent facts. Match the language of the source text (English or Arabic).";
      break;
    case "bullets":
      system =
        "You are a professional note-taking assistant. Extract prioritized bullet points from the note (or from the provided summary). One idea per line, each starting with '- '. Prefer actions, decisions, blockers, owners, and dates when present. Do not invent facts. Match the language of the source text (English or Arabic).";
      break;
    case "actions":
      system =
        'Extract actionable to-do items from the note. Respond with ONLY a JSON array of objects: [{"description":"..."}]. No markdown. Do not invent items not implied by the source.';
      break;
    case "tags":
      system =
        "Suggest 3-6 short topical tags for this note. Respond with ONLY a JSON array of strings. Prefer lowercase single words or short phrases.";
      break;
    case "translate":
      system = `Translate the following note text to ${
        targetLanguage === "ar" ? "Arabic" : "English"
      }. Preserve meaning. Output only the translation.`;
      break;
    default:
      throw new HttpsError("invalid-argument", `Unknown mode: ${mode}`);
  }

  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: system },
      { role: "user", content: user },
    ],
    temperature: 0.3,
  });

  return (response.choices[0]?.message?.content || "").trim();
}

function parseJsonArray(text) {
  try {
    const cleaned = text.replace(/^```json\s*/i, "").replace(/```$/i, "").trim();
    const parsed = JSON.parse(cleaned);
    return Array.isArray(parsed) ? parsed : null;
  } catch (_) {
    return null;
  }
}

/**
 * Apply AI result to a note document (owner path).
 * @returns {Promise<object>} updates applied
 */
async function runNoteAiOnDoc({
  noteRef,
  mode,
  targetLanguage,
  apiKey,
  sourceOverride,
}) {
  const snap = await noteRef.get();
  if (!snap.exists) {
    throw new Error("Note not found");
  }
  const data = snap.data() || {};
  let sourceText = sourceOverride || sourceTextFromNote(data, mode);
  if (!sourceText) {
    throw new Error("No transcript or content to process");
  }

  if (mode === "transcribe") {
    await noteRef.update({
      aiMode: "transcribe",
      aiStatus: "done",
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { aiMode: "transcribe", aiStatus: "done" };
  }

  const openai = new OpenAI({ apiKey });
  await noteRef.update({
    aiStatus: "processing",
    updatedAt: FieldValue.serverTimestamp(),
  });

  try {
    const result = await runGpt({
      openai,
      mode,
      sourceText,
      targetLanguage,
    });

    const updates = {
      aiStatus: "done",
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (mode === "summarize") {
      updates.aiSummary = result;
      updates.aiMode = "summarize";
    } else if (mode === "bullets") {
      updates.aiBulletPoints = result;
      updates.aiMode = "bullets";
    } else if (mode === "actions") {
      const arr = parseJsonArray(result) || [];
      const fresh = arr.map((item, i) => ({
        id: crypto.randomUUID ? crypto.randomUUID() : `ai_${Date.now()}_${i}`,
        description:
          typeof item === "string"
            ? item
            : item.description || item.text || String(item),
        isDone: false,
      }));
      const existing = Array.isArray(data.actionItems) ? data.actionItems : [];
      updates.actionItems = [...existing, ...fresh];
    } else if (mode === "tags") {
      const arr = parseJsonArray(result) || [];
      const tags = arr
        .map((t) => (typeof t === "string" ? t : String(t)))
        .map((t) => t.replace(/^#/, "").trim())
        .filter(Boolean)
        .slice(0, 8);
      const existing = Array.isArray(data.tags) ? data.tags : [];
      updates.tags = Array.from(new Set([...existing, ...tags]));
    } else if (mode === "translate") {
      updates.translatedText = result;
      updates.translatedLanguage = targetLanguage === "ar" ? "ar" : "en";
    }

    await noteRef.update(updates);
    return updates;
  } catch (err) {
    await noteRef.update({
      aiStatus: "error",
      updatedAt: FieldValue.serverTimestamp(),
    });
    throw err;
  }
}

const processNoteAi = onCall(
  {
    region: "us-central1",
    secrets: [openaiApiKey],
    timeoutSeconds: 300,
    memory: "1GiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign in required");
    }
    const uid = request.auth.uid;
    const { noteId, mode, targetLanguage } = request.data || {};
    if (!noteId || typeof noteId !== "string") {
      throw new HttpsError("invalid-argument", "noteId required");
    }
    const allowed = [
      "transcribe",
      "summarize",
      "bullets",
      "actions",
      "tags",
      "translate",
    ];
    if (!allowed.includes(mode)) {
      throw new HttpsError(
        "invalid-argument",
        `mode must be one of: ${allowed.join(", ")}`,
      );
    }

    const db = getFirestore();
    const noteRef = db.collection("users").doc(uid).collection("notes").doc(noteId);

    const snap = await noteRef.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", "Note not found");
    }
    const data = snap.data() || {};

    let sourceText;
    try {
      sourceText = await ensureTranscriptIfNeeded({
        noteRef,
        data,
        apiKey: openaiApiKey.value(),
        mode,
      });
    } catch (e) {
      console.error("[processNoteAi] transcript failed", e);
      throw new HttpsError(
        "failed-precondition",
        e.message || "Could not transcribe audio",
      );
    }

    if (!sourceText && mode === "transcribe") {
      throw new HttpsError(
        "failed-precondition",
        "No transcript yet — wait for auto-transcription after upload",
      );
    }
    if (!sourceText && mode !== "transcribe") {
      throw new HttpsError(
        "failed-precondition",
        data.recording
          ? "Wait for auto-transcription to finish, then try again"
          : "No content or transcript available",
      );
    }

    const updates = await runNoteAiOnDoc({
      noteRef,
      mode,
      targetLanguage,
      apiKey: openaiApiKey.value(),
      sourceOverride: sourceText,
    });

    return { ok: true, mode, updates };
  },
);

exports.processNoteAi = processNoteAi;
exports.runNoteAiOnDoc = runNoteAiOnDoc;
exports.openaiApiKey = openaiApiKey;
