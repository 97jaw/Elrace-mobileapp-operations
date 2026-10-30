/**
 * Isolated codebase: assignment FCM triggers in asia-south1.
 * Avoids me-central-1 upload 403 (same pattern as functions-liveness).
 *
 * Deploy:
 *   firebase deploy --project elrace-new --only \
 *     functions:assignment:onAssignedTodoCreated,functions:assignment:onTodoCompleted,functions:assignment:onAssignmentPushRequest,firestore:rules
 */
const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { emitViaOdoo, ingestToken, odooUserIdForUid } = require("./lib/odoo_notify");
const ticketTriggers = require("./tickets");

initializeApp();

setGlobalOptions({ region: "asia-south1" });

exports.onTicketCreated = ticketTriggers.onTicketCreated;
exports.onTicketUpdated = ticketTriggers.onTicketUpdated;
exports.onTicketCommentCreated = ticketTriggers.onTicketCommentCreated;

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
        channelId: "task_notifications_channel",
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

function memberOdooIds(data) {
  const members = Array.isArray(data && data.assigned_members)
    ? data.assigned_members
    : [];
  const ids = [];
  for (const member of members) {
    const parsed = Number(member && (member.user_id || member.odoo_user_id));
    if (Number.isFinite(parsed) && parsed > 0) ids.push(parsed);
  }
  return ids;
}

/**
 * When a todo is copied under an assignee path (owner_uid !== path uid),
 * notify that assignee via FCM.
 */
exports.onAssignedTodoCreated = onDocumentCreated(
  {
    document: "users/{uid}/todos/{todoId}",
    secrets: [ingestToken],
  },
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

    const routed = await emitViaOdoo({
      type: "task.assigned",
      recipientUids: [uid],
      actorUid: ownerUid,
      model: "firestore.todo",
      resId: todoId,
      values: { assigned_by: assignedBy, task_title: taskTitle },
      eventKey: `assign:${todoId}:${uid}`,
    });
    if (routed.handled) return;

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
 * When an assignee marks a task complete on the owner's document,
 * FCM-notify the owner (assigner). Skips self-complete.
 */
exports.onTodoCompleted = onDocumentUpdated(
  {
    document: "users/{uid}/todos/{todoId}",
    secrets: [ingestToken],
  },
  async (event) => {
    const change = event.data;
    if (!change) return;

    const before = change.before.data() || {};
    const after = change.after.data() || {};
    if (before.is_completed === true || after.is_completed !== true) {
      return;
    }

    const pathUid = event.params.uid;
    const todoId = event.params.todoId;
    const ownerUid = (
      after.owner_uid ||
      after.created_by ||
      after.user_id ||
      pathUid ||
      ""
    ).toString();

    // Only the owner doc — assignee copies would otherwise duplicate pushes.
    if (!ownerUid || pathUid !== ownerUid) {
      return;
    }

    const completedByUid = (after.last_completed_by_uid || "").toString().trim();
    const completedBy =
      (after.last_completed_by_name || "").toString().trim() || "Someone";
    const taskTitle = after.title || "Task";
    const actorOdooId = await odooUserIdForUid(completedByUid);
    const recipientUids =
      ownerUid && completedByUid && ownerUid !== completedByUid ? [ownerUid] : [];
    const odooUserIds = memberOdooIds(after).filter((id) => id !== actorOdooId);
    if (completedByUid && (recipientUids.length || odooUserIds.length)) {
      const routed = await emitViaOdoo({
        type: "task.completed",
        recipientUids,
        odooUserIds,
        actorUid: completedByUid,
        model: "firestore.todo",
        resId: todoId,
        values: { completed_by: completedBy, task_title: taskTitle },
        eventKey: `complete:${todoId}:${completedByUid}`,
      });
      if (routed.handled) return;
    }

    if (!completedByUid || completedByUid === ownerUid) {
      return;
    }

    await sendPushToUserUid({
      uid: ownerUid,
      title: "✅ Task Completed",
      body: `${completedBy} completed: "${taskTitle}"`,
      data: {
        type: "task",
        category: "task",
        task_id: todoId,
        action: "completed",
        is_firebase_task: "true",
      },
    });
  }
);

/**
 * Explicit push requests (Odoo Tickets + task_completed fallbacks).
 * Fields assignee_* identify the *recipient* of the push.
 */
exports.onAssignmentPushRequest = onDocumentCreated(
  {
    document: "assignment_push_requests/{requestId}",
    secrets: [ingestToken],
  },
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
    const action = (data.action || "new_task").toString();
    const taskTitle = data.task_title || "New item";
    const completed =
      action === "task_completed" || action === "completed";
    const notifyType = category === "ticket"
      ? (completed ? "ticket.closed" : "ticket.assigned")
      : (completed ? "task.completed" : "task.assigned");
    const assignedBy = (data.assigned_by || "Someone").toString();
    const completedBy = (
      data.completed_by || data.assigned_by || "Someone"
    ).toString();
    const routed = await emitViaOdoo({
      type: notifyType,
      recipientUids: [uid],
      model: category === "ticket" ? "firestore.ticket" : "firestore.todo",
      resId: String(data.task_id || ""),
      values: completed
        ? {
            completed_by: completedBy,
            task_title: taskTitle,
            ticket_title: taskTitle,
          }
        : {
            assigned_by: assignedBy,
            task_title: taskTitle,
            ticket_title: taskTitle,
            assignee: assignedBy,
          },
      eventKey: `${notifyType}:${data.task_id || ""}:${uid}`,
    });
    if (routed.handled) return;

    let title;
    let body;
    if (action === "task_completed" || action === "completed") {
      const completedBy =
        (data.completed_by || data.assigned_by || "").toString().trim() ||
        "Someone";
      title =
        category === "ticket" ? "✅ Ticket Completed" : "✅ Task Completed";
      body = `${completedBy} completed: "${taskTitle}"`;
    } else {
      const assignedBy = data.assigned_by || "Someone";
      title =
        category === "ticket"
          ? "🎫 New Ticket Assigned"
          : "📋 New Task Assigned";
      body = `${assignedBy} assigned you: "${taskTitle}"`;
    }

    await sendPushToUserUid({
      uid,
      title,
      body,
      data: {
        type: category,
        category,
        task_id: String(data.task_id || ""),
        action:
          action === "task_completed" || action === "completed"
            ? "completed"
            : "new_task",
        is_firebase_task: isFirebase ? "true" : "false",
      },
    });
  }
);

/**
 * Comment on the owner's todo. Assignee copies are ignored so one comment
 * does not fan out twice.
 */
exports.onTodoCommentCreated = onDocumentCreated(
  {
    document: "users/{uid}/todos/{todoId}/comments/{commentId}",
    secrets: [ingestToken],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const comment = snap.data() || {};
    const uid = event.params.uid;
    const todoId = event.params.todoId;
    const todoSnap = await db.collection("users").doc(uid).collection("todos").doc(todoId).get();
    if (!todoSnap.exists) return;
    const todo = todoSnap.data() || {};
    const ownerUid = (todo.owner_uid || uid).toString();
    if (ownerUid !== uid) return;

    const authorUid = (comment.author_id || "").toString();
    const authorOdooId = await odooUserIdForUid(authorUid);
    const recipientUids = ownerUid && ownerUid !== authorUid ? [ownerUid] : [];
    const odooUserIds = memberOdooIds(todo).filter((id) => id !== authorOdooId);
    if (!recipientUids.length && !odooUserIds.length) return;

    const sender = (comment.author_name || "Someone").toString();
    const text = (comment.content || comment.body || "").toString().slice(0, 120);
    await emitViaOdoo({
      type: "task.comment",
      recipientUids,
      odooUserIds,
      actorUid: authorUid,
      model: "firestore.todo",
      resId: todoId,
      values: { sender, comment: text },
      eventKey: `comment:${todoId}:${event.params.commentId}`,
    });
  }
);

exports.onTaskDeadlines = onSchedule(
  {
    schedule: "every 5 minutes",
    secrets: [ingestToken],
  },
  async () => {
    const now = Date.now();
    const windows = [
      {
        code: "24h",
        type: "task.deadline_24h",
        start: now + (23 * 60 + 55) * 60 * 1000,
        end: now + 24 * 60 * 60 * 1000,
      },
      {
        code: "1h",
        type: "task.deadline_1h",
        start: now + 55 * 60 * 1000,
        end: now + 60 * 60 * 1000,
      },
    ];
    for (const window of windows) {
      const snap = await db.collectionGroup("todos")
        .where("is_completed", "==", false)
        .where("due_date", ">", Timestamp.fromMillis(window.start))
        .where("due_date", "<=", Timestamp.fromMillis(window.end))
        .get();
      for (const doc of snap.docs) {
        const data = doc.data() || {};
        const pathUid = doc.ref.parent.parent ? doc.ref.parent.parent.id : "";
        const ownerUid = (data.owner_uid || pathUid).toString();
        if (!ownerUid || pathUid !== ownerUid) continue;
        const dueAt = data.due_date && data.due_date.toDate
          ? data.due_date.toDate().toISOString()
          : String(window.end);
        const odooUserIds = memberOdooIds(data);
        const recipientUids = odooUserIds.length ? [] : [ownerUid];
        const routed = await emitViaOdoo({
          type: window.type,
          recipientUids,
          odooUserIds,
          model: "firestore.todo",
          resId: doc.id,
          values: { task_title: data.title || "Task" },
          eventKey: `${doc.id}:${dueAt}:${window.code}`,
        });
        if (!routed.handled) {
          console.log(`Deadline ${window.code} not taken over for ${doc.id}`);
        }
      }
    }
  }
);
