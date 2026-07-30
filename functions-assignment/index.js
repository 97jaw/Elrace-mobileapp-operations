/**
 * Isolated codebase: assignment FCM triggers in asia-south1.
 * Avoids me-central-1 upload 403 (same pattern as functions-liveness).
 *
 * Deploy:
 *   firebase deploy --project elrace-new --only \
 *     functions:assignment:onAssignedTodoCreated,functions:assignment:onAssignmentPushRequest,firestore:rules
 */
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

setGlobalOptions({ region: "asia-south1" });

const db = getFirestore();
const messaging = getMessaging();

async function sendPushToUserUid({ uid, title, body, data }) {
  const tokensSnap = await db
    .collection("users")
    .doc(uid)
    .collection("fcm_tokens")
    .get();

  if (tokensSnap.empty) {
    console.log(`No FCM tokens for uid=${uid}`);
    return { successCount: 0, failCount: 0 };
  }

  const tokens = tokensSnap.docs.map((d) => ({ token: d.id, uid }));
  const messages = tokens.map((t) => ({
    token: t.token,
    notification: { title, body },
    data: {
      ...Object.fromEntries(
        Object.entries(data || {}).map(([k, v]) => [k, String(v ?? "")])
      ),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: {
      priority: "high",
      notification: {
        channelId: "task_notifications",
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
          "content-available": 1,
        },
      },
    },
  }));

  const results = await Promise.allSettled(
    messages.map((msg) => messaging.send(msg))
  );

  let successCount = 0;
  let failCount = 0;
  const tokensToRemove = [];
  results.forEach((result, index) => {
    if (result.status === "fulfilled") {
      successCount++;
    } else {
      failCount++;
      const error = result.reason;
      if (
        error?.code === "messaging/invalid-registration-token" ||
        error?.code === "messaging/registration-token-not-registered"
      ) {
        tokensToRemove.push(tokens[index]);
      }
    }
  });

  if (tokensToRemove.length > 0) {
    const batch = db.batch();
    for (const t of tokensToRemove) {
      batch.delete(
        db.collection("users").doc(t.uid).collection("fcm_tokens").doc(t.token)
      );
    }
    await batch.commit();
  }

  console.log(
    `Assignment push to ${uid}: ${successCount} ok, ${failCount} failed`
  );
  return { successCount, failCount };
}

async function resolveUidFromOdooUserId(odooUserId) {
  if (odooUserId == null) return null;
  const idStr = String(odooUserId);
  const preferred = `odoo_${idStr}`;
  const preferredDoc = await db.collection("users").doc(preferred).get();
  if (preferredDoc.exists) return preferred;

  const snap = await db
    .collection("users")
    .where("odoo_user_id", "==", Number(idStr) || idStr)
    .limit(1)
    .get();
  if (!snap.empty) return snap.docs[0].id;

  const snap2 = await db
    .collection("users")
    .where("odoo_user_id", "==", idStr)
    .limit(1)
    .get();
  if (!snap2.empty) return snap2.docs[0].id;

  return null;
}

/**
 * When a todo is copied under an assignee path (owner_uid !== path uid),
 * notify that assignee via FCM.
 */
exports.onAssignedTodoCreated = onDocumentCreated(
  "users/{uid}/todos/{todoId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const uid = event.params.uid;
    const todoId = event.params.todoId;
    const ownerUid = data.owner_uid || data.created_by || data.user_id || "";

    if (!ownerUid || ownerUid === uid) {
      return;
    }

    const title = "📋 New Task Assigned";
    const assignedBy = data.created_by_name || data.owner_name || "Someone";
    const taskTitle = data.title || "New task";
    const body = `${assignedBy} assigned you: "${taskTitle}"`;

    await sendPushToUserUid({
      uid,
      title,
      body,
      data: {
        type: "task",
        category: "task",
        task_id: todoId,
        action: "new_task",
        is_firebase_task: "true",
      },
    });
  }
);

/**
 * Explicit assignment push requests (Odoo Tickets + optional clients).
 */
exports.onAssignmentPushRequest = onDocumentCreated(
  "assignment_push_requests/{requestId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    let uid = (data.assignee_firebase_uid || "").toString().trim();
    if (!uid && data.assignee_odoo_user_id != null) {
      uid = (await resolveUidFromOdooUserId(data.assignee_odoo_user_id)) || "";
    }
    if (!uid) {
      console.log(
        "assignment_push_requests: could not resolve assignee uid",
        data
      );
      return;
    }

    const isFirebase =
      data.is_firebase_task === true || data.is_firebase_task === "true";
    const category = (
      data.category || (isFirebase ? "task" : "ticket")
    ).toString();
    const taskTitle = data.task_title || "New item";
    const assignedBy = data.assigned_by || "Someone";
    const title =
      category === "ticket" ? "🎫 New Ticket Assigned" : "📋 New Task Assigned";
    const body = `${assignedBy} assigned you: "${taskTitle}"`;

    await sendPushToUserUid({
      uid,
      title,
      body,
      data: {
        type: category,
        category,
        task_id: String(data.task_id || ""),
        action: "new_task",
        is_firebase_task: isFirebase ? "true" : "false",
      },
    });
  }
);
