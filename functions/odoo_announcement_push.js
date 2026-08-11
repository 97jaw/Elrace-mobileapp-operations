const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { defineSecret, defineString } = require("firebase-functions/params");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

/**
 * Circular / Announcement publish fan-out.
 *
 * Trigger: Firestore odoo_push_jobs/{jobId} created by Odoo on Publish.
 * Token source (recommended): POST Odoo /api/internal/staff_fcm_tokens
 *   Header X-Elrace-Push-Token = elrace.firebase.push_service_token
 *
 * maxInstances: 1 so managers publishing one-by-one are processed serially
 * without overlapping full-company FCM storms.
 */

const pushServiceToken = defineSecret("ELRACE_PUSH_SERVICE_TOKEN");
const odooBaseUrl = defineString("ELRACE_ODOO_BASE_URL", {
  default: "https://erp.elrace.com",
});

const FCM_BATCH = 500;

function chunk(arr, size) {
  const out = [];
  for (let i = 0; i < arr.length; i += size) {
    out.push(arr.slice(i, i + size));
  }
  return out;
}

async function fetchStaffTokens({ baseUrl, serviceToken, job }) {
  const url = `${baseUrl.replace(/\/$/, "")}/api/internal/staff_fcm_tokens`;
  const body = {
    general: job.general !== false,
    company_id: job.company_id || null,
    user_ids: Array.isArray(job.user_ids) ? job.user_ids : [],
  };
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Elrace-Push-Token": serviceToken,
    },
    body: JSON.stringify(body),
  });
  const text = await resp.text();
  let data = {};
  try {
    data = JSON.parse(text);
  } catch (_) {
    data = {};
  }
  if (!resp.ok || data.status !== "success") {
    throw new Error(
      `staff_fcm_tokens HTTP ${resp.status}: ${text.slice(0, 300)}`
    );
  }
  return Array.isArray(data.tokens) ? data.tokens.filter(Boolean) : [];
}

async function sendFcmBatches(messaging, tokens, title, body, dataPayload) {
  let success = 0;
  let failure = 0;
  const stringData = {};
  for (const [k, v] of Object.entries(dataPayload || {})) {
    if (v === undefined || v === null) continue;
    stringData[String(k)] = String(v);
  }

  for (const batch of chunk(tokens, FCM_BATCH)) {
    const message = {
      tokens: batch,
      notification: { title, body },
      data: stringData,
      android: {
        priority: "high",
        notification: {
          channelId: "high_importance_channel",
          priority: "high",
          defaultSound: true,
        },
      },
      apns: {
        headers: { "apns-priority": "10", "apns-push-type": "alert" },
        payload: {
          aps: {
            alert: { title, body },
            sound: "default",
          },
        },
      },
    };
    const res = await messaging.sendEachForMulticast(message);
    success += res.successCount || 0;
    failure += res.failureCount || 0;
  }
  return { success, failure };
}

exports.onOdooAnnouncementPushJob = onDocumentCreated(
  {
    document: "odoo_push_jobs/{jobId}",
    // Match existing Functions (notes/sign). me-central-1 returns 403 on this project.
    region: "us-central1",
    secrets: [pushServiceToken],
    maxInstances: 1,
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const jobId = event.params.jobId;
    const job = snap.data() || {};
    const db = getFirestore();
    const messaging = getMessaging();
    const ref = snap.ref;

    if (job.type && job.type !== "announcement_publish") {
      console.log(`Skip job ${jobId}: type=${job.type}`);
      return;
    }
    if (job.status && job.status !== "pending") {
      console.log(`Skip job ${jobId}: status=${job.status}`);
      return;
    }

    await ref.set(
      {
        status: "processing",
        started_at: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    try {
      const baseUrl = (job.odoo_base_url || odooBaseUrl.value() || "").trim();
      if (!baseUrl) {
        throw new Error("Missing odoo_base_url / ELRACE_ODOO_BASE_URL");
      }
      const serviceToken = pushServiceToken.value();
      if (!serviceToken) {
        throw new Error("Missing ELRACE_PUSH_SERVICE_TOKEN secret");
      }

      const tokens = await fetchStaffTokens({
        baseUrl,
        serviceToken,
        job,
      });
      console.log(
        `Job ${jobId}: fetched ${tokens.length} tokens (record=${job.record_id})`
      );

      if (!tokens.length) {
        await ref.set(
          {
            status: "done",
            token_count: 0,
            success_count: 0,
            failure_count: 0,
            finished_at: FieldValue.serverTimestamp(),
            note: "no_tokens",
          },
          { merge: true }
        );
        return;
      }

      const title = (job.title || "Announcement published").toString();
      const body = (job.body || "").toString();
      const category = (job.category || "announcement").toString();
      const dataPayload = {
        type: category,
        category,
        model: "odx.announcement",
        record_id: job.record_id || "",
        status: "published",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      };

      const { success, failure } = await sendFcmBatches(
        messaging,
        tokens,
        title,
        body,
        dataPayload
      );

      await ref.set(
        {
          status: "done",
          token_count: tokens.length,
          success_count: success,
          failure_count: failure,
          finished_at: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      console.log(
        `Job ${jobId}: done success=${success} failure=${failure}`
      );
    } catch (err) {
      console.error(`Job ${jobId} failed:`, err);
      await ref.set(
        {
          status: "failed",
          error: String(err && err.message ? err.message : err).slice(0, 500),
          finished_at: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
      throw err;
    }
  }
);
