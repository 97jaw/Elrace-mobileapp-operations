const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { emitViaOdoo, ingestToken } = require("./lib/odoo_notify");

const triggerOptions = (document) => ({ document, secrets: [ingestToken] });

async function resolveAssignee(assigneeId) {
  const text = (assigneeId == null ? "" : String(assigneeId)).trim();
  if (!text) return null;
  if (!/^\d+$/.test(text)) return { uid: text };
  const num = Number(text);
  const db = getFirestore();
  let snap = await db.collection("users").where("employee_id", "==", num).limit(1).get();
  if (snap.empty) {
    snap = await db.collection("users").where("odoo_user_id", "==", num).limit(1).get();
  }
  if (snap.empty) return null;
  return { uid: snap.docs[0].id };
}

async function emitTicket({
  type,
  ticketId,
  actorUid,
  ownerUid,
  assigneeId,
  title,
  assigneeName,
  summary,
  eventKey,
}) {
  const people = [];
  if (ownerUid) people.push(ownerUid);
  const assignee = await resolveAssignee(assigneeId);
  if (assignee && assignee.uid) people.push(assignee.uid);
  const recipientUids = [...new Set(people.filter((uid) => uid && uid !== actorUid))];
  if (!recipientUids.length) return;
  await emitViaOdoo({
    type,
    recipientUids,
    actorUid,
    model: "firestore.ticket",
    resId: ticketId,
    values: {
      ticket_title: title || "Ticket",
      assignee: assigneeName || "",
      update_summary: summary || "",
    },
    eventKey,
  });
}

async function onTicketCreated(event) {
  const snap = event.data;
  if (!snap) return;
  const data = snap.data() || {};
  if (!data.assignee_id) return;
  const actorUid = event.params.uid;
  await emitTicket({
    type: "ticket.assigned",
    ticketId: event.params.ticketId,
    actorUid,
    ownerUid: (data.owner_uid || actorUid).toString(),
    assigneeId: data.assignee_id,
    title: data.title,
    assigneeName: data.assignee_name,
    eventKey: `ticket.assigned:${event.params.ticketId}:${data.assignee_id}`,
  });
}

async function onTicketUpdated(event) {
  const change = event.data;
  if (!change) return;
  const before = change.before.data() || {};
  const after = change.after.data() || {};
  const actorUid = event.params.uid;
  const ticketId = event.params.ticketId;
  const ownerUid = (after.owner_uid || actorUid).toString();
  const beforeAssignee = (before.assignee_id || "").toString();
  const afterAssignee = (after.assignee_id || "").toString();
  const beforeStatus = (before.status || "").toString();
  const afterStatus = (after.status || "").toString();
  const base = {
    ticketId,
    actorUid,
    ownerUid,
    assigneeId: after.assignee_id,
    title: after.title,
    assigneeName: after.assignee_name,
  };

  if (beforeStatus !== afterStatus && afterStatus === "closed") {
    await emitTicket({
      ...base,
      type: "ticket.closed",
      eventKey: `ticket.closed:${ticketId}`,
    });
    return;
  }
  if (!beforeAssignee && afterAssignee) {
    await emitTicket({
      ...base,
      type: "ticket.assigned",
      eventKey: `ticket.assigned:${ticketId}:${afterAssignee}`,
    });
    return;
  }
  if (beforeAssignee && afterAssignee && beforeAssignee !== afterAssignee) {
    await emitTicket({
      ...base,
      type: "ticket.reassigned",
      eventKey: `ticket.reassigned:${ticketId}:${afterAssignee}`,
    });
    return;
  }
  if (beforeStatus !== afterStatus) {
    await emitTicket({
      ...base,
      type: "ticket.updated",
      summary: `Status changed to ${afterStatus}`,
      eventKey: `ticket.updated:${ticketId}:${afterStatus}`,
    });
  }
}

async function onTicketComment(event) {
  const snap = event.data;
  if (!snap) return;
  const comment = snap.data() || {};
  const actorUid = (comment.author_id || event.params.uid || "").toString();
  const ticketId = event.params.ticketId;
  const db = getFirestore();
  const ticketSnap = await db
    .collection("users")
    .doc(event.params.uid)
    .collection("tickets")
    .doc(ticketId)
    .get();
  if (!ticketSnap.exists) return;
  const ticket = ticketSnap.data() || {};
  const text = (comment.content || comment.body || "").toString().slice(0, 120);
  await emitTicket({
    type: "ticket.updated",
    ticketId,
    actorUid,
    ownerUid: (ticket.owner_uid || event.params.uid).toString(),
    assigneeId: ticket.assignee_id,
    title: ticket.title,
    assigneeName: ticket.assignee_name,
    summary: text,
    eventKey: `ticket.updated:${ticketId}:comment:${event.params.commentId}`,
  });
}

exports.onTicketCreated = onDocumentCreated(
  triggerOptions("users/{uid}/tickets/{ticketId}"),
  onTicketCreated,
);
exports.onTicketUpdated = onDocumentUpdated(
  triggerOptions("users/{uid}/tickets/{ticketId}"),
  onTicketUpdated,
);
exports.onTicketCommentCreated = onDocumentCreated(
  triggerOptions("users/{uid}/tickets/{ticketId}/comments/{commentId}"),
  onTicketComment,
);
