const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

const ROLE_LABEL = {
  site_engineer: "Site Engineer",
  projects_manager: "Projects Manager",
};

/**
 * Pure planner: pick the single notification event for one write.
 * Returns null when nothing should be sent.
 *
 * @param {object|null} before
 * @param {object|null} after
 * @param {string} docId
 */
function buildTimesheetApprovalNotifyPlan(before, after, docId) {
  if (!after || typeof after !== "object") return null;
  const id = String(docId || "").trim();
  if (!id) return null;

  const ownerUid = String(after.owner_uid || "").trim();
  const ownerName = String(after.owner_name || "Someone").trim() || "Someone";
  const fileName = String(after.file_name || "Timesheet.pdf").trim() || "Timesheet.pdf";
  const projectName = String(after.project_name || "").trim();
  const status = String(after.status || "").trim();
  const approverUids = Array.isArray(after.approver_uids)
    ? after.approver_uids.map((u) => String(u))
    : [];
  const approvers =
    after.approvers && typeof after.approvers === "object" ? after.approvers : {};

  // Created → push-only to every approver.
  if (!before) {
    if (approverUids.length === 0) return null;
    let body = `${ownerName} sent ${fileName}`;
    if (projectName) body += ` · ${projectName}`;
    return {
      kind: "waiting",
      eventId: `${id}:waiting`,
      store: false,
      recipientUids: approverUids,
      title: "Timesheet waiting for your approval",
      body,
      type: "timesheet_approval.waiting",
      category: "timesheet_approval_waiting",
    };
  }

  const beforeStatus = String(before.status || "").trim();
  const beforeApprovers =
    before.approvers && typeof before.approvers === "object"
      ? before.approvers
      : {};

  // Rejected (wins over partial/full approve on the same write).
  if (status === "rejected" && beforeStatus !== "rejected") {
    const actor = _findNewlyActed(beforeApprovers, approvers, "rejected");
    if (!actor || !ownerUid) return null;
    const role = ROLE_LABEL[actor.role] || actor.role || "Approver";
    return {
      kind: "rejected",
      eventId: `${id}:rejected:${actor.uid}`,
      store: true,
      recipientUids: [ownerUid],
      title: "Timesheet rejected",
      body: `${actor.name} (${role}) rejected ${fileName}`,
      type: "timesheet_approval.rejected",
      category: "timesheet_approval",
    };
  }

  // Fully approved.
  if (status === "approved" && beforeStatus !== "approved") {
    if (!ownerUid) return null;
    const names = _approvedNames(approvers);
    const by = names.length ? names.join(", ") : "approvers";
    return {
      kind: "approved_all",
      eventId: `${id}:approved:all`,
      store: true,
      recipientUids: [ownerUid],
      title: "Timesheet approved",
      body: `${fileName} approved by ${by}`,
      type: "timesheet_approval.approved",
      category: "timesheet_approval",
    };
  }

  // One approver approved; still waiting on the other.
  if (status === "pending") {
    const actor = _findNewlyActed(beforeApprovers, approvers, "approved");
    if (!actor || !ownerUid) return null;
    const other = _otherPendingApprover(approvers, actor.uid);
    const waitingFor = other?.name || "the other approver";
    const role = ROLE_LABEL[actor.role] || actor.role || "Approver";
    return {
      kind: "approved_partial",
      eventId: `${id}:approved:${actor.uid}`,
      store: true,
      recipientUids: [ownerUid],
      title: `Approved by ${actor.name} (${role})`,
      body: `${fileName} — waiting for ${waitingFor}`,
      type: "timesheet_approval.approved",
      category: "timesheet_approval",
    };
  }

  return null;
}

function _findNewlyActed(beforeApprovers, afterApprovers, status) {
  for (const [uid, entry] of Object.entries(afterApprovers || {})) {
    if (!entry || typeof entry !== "object") continue;
    if (String(entry.status || "") !== status) continue;
    const prev = beforeApprovers?.[uid];
    const prevStatus = prev && typeof prev === "object" ? String(prev.status || "") : "";
    if (prevStatus === status) continue;
    return {
      uid,
      name: String(entry.name || "Someone").trim() || "Someone",
      role: String(entry.role || "").trim(),
    };
  }
  return null;
}

function _otherPendingApprover(approvers, excludeUid) {
  for (const [uid, entry] of Object.entries(approvers || {})) {
    if (uid === excludeUid) continue;
    if (!entry || typeof entry !== "object") continue;
    if (String(entry.status || "") === "pending") {
      return {
        uid,
        name: String(entry.name || "Someone").trim() || "Someone",
      };
    }
  }
  // Fall back to any other named approver (already acted).
  for (const [uid, entry] of Object.entries(approvers || {})) {
    if (uid === excludeUid) continue;
    if (!entry || typeof entry !== "object") continue;
    return {
      uid,
      name: String(entry.name || "Someone").trim() || "Someone",
    };
  }
  return null;
}

function _approvedNames(approvers) {
  const names = [];
  for (const entry of Object.values(approvers || {})) {
    if (!entry || typeof entry !== "object") continue;
    if (String(entry.status || "") !== "approved") continue;
    const name = String(entry.name || "").trim();
    if (name) names.push(name);
  }
  return names;
}

/**
 * Notify SE/PM on create; notify the foreman on approve / reject.
 * Results are stored under users/{owner}/app_notifications/{eventId}.
 */
exports.onTimesheetApprovalWritten = onDocumentWritten(
  {
    document: "timesheet_approvals/{id}",
    region: "us-central1",
  },
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    if (!afterSnap?.exists) return;

    const docId = event.params.id;
    const before = beforeSnap?.exists ? beforeSnap.data() || null : null;
    const after = afterSnap.data() || {};
    const plan = buildTimesheetApprovalNotifyPlan(before, after, docId);
    if (!plan) return;

    const db = getFirestore();
    const messaging = getMessaging();

    let fsNotificationId = "";
    if (plan.store && plan.recipientUids.length === 1) {
      const ownerUid = plan.recipientUids[0];
      fsNotificationId = plan.eventId;
      try {
        await db
          .collection("users")
          .doc(ownerUid)
          .collection("app_notifications")
          .doc(fsNotificationId)
          .set(
            {
              title: plan.title,
              body: plan.body,
              type: plan.type,
              category: plan.category,
              model: "firestore.timesheet_approval",
              res_id: docId,
              read: false,
              created_at: FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
      } catch (e) {
        console.error(`timesheet approval store notify failed: ${e}`);
      }
    }

    for (const uid of plan.recipientUids) {
      if (!uid) continue;
      try {
        await _sendToUser({
          db,
          messaging,
          uid,
          title: plan.title,
          body: plan.body,
          type: plan.type,
          category: plan.category,
          resId: docId,
          fsNotificationId,
        });
      } catch (e) {
        console.error(`timesheet approval push to ${uid} failed: ${e}`);
      }
    }
  }
);

async function _sendToUser({
  db,
  messaging,
  uid,
  title,
  body,
  type,
  category,
  resId,
  fsNotificationId,
}) {
  const tokensSnap = await db
    .collection("users")
    .doc(uid)
    .collection("fcm_tokens")
    .get();
  if (tokensSnap.empty) {
    console.log(`No FCM tokens for timesheet approval recipient ${uid}`);
    return;
  }

  const data = {
    nv: "1",
    type,
    category,
    action: "open_record",
    model: "firestore.timesheet_approval",
    res_id: String(resId),
    click_action: "FLUTTER_NOTIFICATION_CLICK",
  };
  if (fsNotificationId) {
    data.fs_notification_id = fsNotificationId;
  }

  const messages = tokensSnap.docs.map((tokenDoc) => ({
    token: tokenDoc.id,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: {
        channelId: "chat_messages",
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
  }));

  const results = await Promise.allSettled(
    messages.map((msg) => messaging.send(msg))
  );

  const tokensToRemove = [];
  let ok = 0;
  results.forEach((result, index) => {
    if (result.status === "fulfilled") {
      ok++;
      return;
    }
    const error = result.reason;
    console.log(
      `Timesheet approval send failed uid=${uid} code=${error?.code || "unknown"}`
    );
    if (
      error?.code === "messaging/invalid-registration-token" ||
      error?.code === "messaging/registration-token-not-registered"
    ) {
      tokensToRemove.push(tokensSnap.docs[index].id);
    }
  });

  if (tokensToRemove.length > 0) {
    const batch = db.batch();
    for (const token of tokensToRemove) {
      batch.delete(
        db.collection("users").doc(uid).collection("fcm_tokens").doc(token)
      );
    }
    await batch.commit();
    console.log(`Removed ${tokensToRemove.length} invalid token(s) for ${uid}`);
  }

  console.log(
    `Timesheet approval notify ${uid}: ${ok}/${messages.length} (${type})`
  );
}

exports.buildTimesheetApprovalNotifyPlan = buildTimesheetApprovalNotifyPlan;
