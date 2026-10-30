const { defineSecret, defineString } = require("firebase-functions/params");
const { getFirestore } = require("firebase-admin/firestore");

const odooBaseUrl = defineString("ELRACE_ODOO_BASE_URL", {
  default: "https://erp.elrace.com",
});
const ingestToken = defineSecret("ELRACE_NOTIFY_INGEST_TOKEN");

async function odooUserIdForUid(uid) {
  if (!uid) return null;
  const doc = await getFirestore().collection("users").doc(String(uid)).get();
  if (!doc.exists) return null;
  const parsed = Number(doc.get("odoo_user_id"));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

async function postEmit(url, token, body) {
  return fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Notify-Token": token,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(8000),
  });
}

/**
 * Ask Odoo to deliver a notification. Never throws.
 * recipientUids are Firebase uids; odooUserIds are res.users ids.
 */
async function emitViaOdoo({
  type,
  recipientUids,
  odooUserIds,
  actorUid,
  model,
  resId,
  values,
  params,
  eventKey,
} = {}) {
  try {
    const ids = new Set();
    if (Array.isArray(odooUserIds)) {
      for (const item of odooUserIds) {
        const parsed = Number(item);
        if (Number.isFinite(parsed) && parsed > 0) ids.add(parsed);
      }
    }
    if (Array.isArray(recipientUids)) {
      for (const uid of recipientUids) {
        const resolved = await odooUserIdForUid(uid);
        if (resolved) ids.add(resolved);
      }
    }
    if (!type || ids.size === 0) return { handled: false };

    const token = ingestToken.value();
    if (!token) return { handled: false };
    const base = String(odooBaseUrl.value() || "https://erp.elrace.com").replace(/\/$/, "");
    const url = `${base}/api/internal/notify/emit`;
    const payload = {
      type,
      recipients: { odoo_user_ids: [...ids] },
      actor_odoo_user_id: actorUid ? await odooUserIdForUid(actorUid) : null,
      model: model || null,
      res_id: resId == null ? null : String(resId),
      values: values && typeof values === "object" ? values : {},
      params: params && typeof params === "object" ? params : {},
      event_key: eventKey || null,
    };

    let response;
    try {
      response = await postEmit(url, token, payload);
      if (response.status >= 500) {
        response = await postEmit(url, token, payload);
      }
    } catch (error) {
      response = await postEmit(url, token, payload);
    }

    const text = await response.text();
    let data = {};
    try {
      data = JSON.parse(text);
    } catch (_) {
      data = {};
    }
    if (response.status >= 500) return { handled: false };
    return { handled: data.handled === true };
  } catch (error) {
    console.error("emitViaOdoo failed", error && error.message ? error.message : error);
    return { handled: false };
  }
}

module.exports = {
  emitViaOdoo,
  odooUserIdForUid,
  odooBaseUrl,
  ingestToken,
};
