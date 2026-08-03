const { setGlobalOptions } = require("firebase-functions/v2");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getStorage } = require("firebase-admin/storage");

initializeApp();

setGlobalOptions({ region: "me-central-1" });

const db = getFirestore();
const messaging = getMessaging();
const storage = getStorage();

/** AWS Rekognition region for timesheet face mocks (liveness callables live in functions-liveness/). */
const AWS_REKOGNITION_REGION = "ap-south-1";

/**
 * Cloud Function: Send push notification when a new chat message is created.
 *
 * Triggers on: chats/{chatId}/messages/{messageId}
 *
 * For each member of the chat (except the sender):
 *   1. Look up their FCM tokens from users/{uid}/fcm_tokens
 *   2. Send a push notification with the message preview
 *   3. Include chat metadata in the data payload for navigation
 */
exports.onNewChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const messageData = snap.data();
    const chatId = event.params.chatId;
    const senderId = messageData.sender_id;

    if (!senderId) {
      console.log("No sender_id in message, skipping");
      return;
    }

    // Get chat document to find members and chat info
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) {
      console.log(`Chat ${chatId} not found`);
      return;
    }

    const chatData = chatDoc.data();
    const memberIds = chatData.member_ids || [];
    const chatType = chatData.type || "dm";

    // Get sender name for notification title
    let senderName = "Someone";
    try {
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (senderDoc.exists) {
        senderName = senderDoc.data().name || senderDoc.data().display_name || "Someone";
      }
    } catch (e) {
      console.log(`Could not get sender name: ${e}`);
    }

    // Build notification content
    const title = chatType === "dm"
      ? senderName
      : `${chatData.title || "Group"} • ${senderName}`;

    let body = "";
    switch (messageData.type) {
      case "text":
        body = messageData.text || "";
        break;
      case "image":
        body = "📷 Photo";
        break;
      case "file":
        body = "📎 File";
        break;
      case "audio":
        body = "🎵 Voice message";
        break;
      case "video":
        body = "🎬 Video";
        break;
      default:
        body = "New message";
    }

    // Collect FCM tokens for all members except sender
    const tokens = [];
    for (const memberId of memberIds) {
      if (memberId === senderId) continue; // Don't notify sender

      try {
        const tokensSnap = await db
          .collection("users")
          .doc(memberId)
          .collection("fcm_tokens")
          .get();

        tokensSnap.forEach((tokenDoc) => {
          tokens.push({
            token: tokenDoc.id,
            uid: memberId,
          });
        });
      } catch (e) {
        console.log(`Could not get tokens for ${memberId}: ${e}`);
      }
    }

    if (tokens.length === 0) {
      console.log("No FCM tokens found for recipients");
      return;
    }

    console.log(`Sending to ${tokens.length} token(s) for chat ${chatId}`);

    // Build the chat title for the recipient
    // For DM, the title should be the sender's name
    const chatTitle = chatType === "dm" ? senderName : (chatData.title || "Chat");

    // Send notifications
    const messages = tokens.map((t) => ({
      token: t.token,
      notification: {
        title: title,
        body: body,
      },
      data: {
        type: "chat_message",
        category: "chat_message",
        chat_id: chatId,
        chat_title: chatTitle,
        chat_type: chatType,
        sender_id: senderId,
        sender_name: senderName,
        message_type: messageData.type || "text",
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        ttl: 300000,
        notification: {
          channelId: "chat_messages",
          priority: "high",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: title,
              body: body,
            },
            badge: 0,
            sound: "default",
            "mutable-content": 1,
            "content-available": 1,
          },
        },
      },
    }));

    // Send all notifications (handle failures gracefully)
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
        // Remove invalid tokens
        if (
          error?.code === "messaging/invalid-registration-token" ||
          error?.code === "messaging/registration-token-not-registered"
        ) {
          tokensToRemove.push(tokens[index]);
        }
      }
    });

    // Clean up invalid tokens
    if (tokensToRemove.length > 0) {
      const batch = db.batch();
      for (const t of tokensToRemove) {
        batch.delete(
          db.collection("users").doc(t.uid).collection("fcm_tokens").doc(t.token)
        );
      }
      await batch.commit();
      console.log(`Removed ${tokensToRemove.length} invalid token(s)`);
    }

    console.log(
      `Notifications sent: ${successCount} success, ${failCount} failed`
    );

    // ── Update all members' userChats timestamps ──────────────
    // This ensures the chat bubbles to the top of every member's chat list
    // when a new message is sent (especially important for group/role chats).
    try {
      const tsBatch = db.batch();
      for (const memberId of memberIds) {
        if (memberId === senderId) continue; // Sender already updated client-side
        tsBatch.set(
          db.collection("users").doc(memberId).collection("user_chats").doc(chatId),
          {
            updated_at: require("firebase-admin/firestore").FieldValue.serverTimestamp(),
            has_messages: true,
          },
          { merge: true }
        );
      }
      await tsBatch.commit();
      console.log(`Updated userChats timestamps for ${memberIds.length - 1} member(s)`);
    } catch (tsErr) {
      console.log(`Could not update member timestamps: ${tsErr}`);
    }
  }
);

/**
 * Scheduled Cloud Function: Clean up expired unsigned signable documents.
 *
 * Runs every hour. Finds signable_doc messages where:
 *   - expires_at < now
 *   - sign_status != 'signed'
 * Then deletes the message doc and its PDF from Storage.
 */
exports.cleanupExpiredSignableDocs = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "UTC",
    retryCount: 1,
  },
  async (event) => {
    const now = new Date();
    console.log(`[Cleanup] Running expired signable doc cleanup at ${now.toISOString()}`);

    // Query all chats
    const chatsSnap = await db.collection("chats").get();
    let deletedCount = 0;
    let errorCount = 0;

    for (const chatDoc of chatsSnap.docs) {
      try {
        // Find expired, unsigned signable docs in this chat
        const messagesSnap = await chatDoc.ref
          .collection("messages")
          .where("type", "==", "signable_doc")
          .where("expires_at", "<", now)
          .get();

        for (const msgDoc of messagesSnap.docs) {
          const data = msgDoc.data();

          // Skip if already signed — signed docs stay forever
          if (data.sign_status === "signed") continue;

          try {
            // Delete PDF from Storage if path exists
            if (data.media_path) {
              try {
                await storage.bucket().file(data.media_path).delete();
                console.log(`[Cleanup] Deleted file: ${data.media_path}`);
              } catch (storageErr) {
                // File may already be gone, that's fine
                console.log(`[Cleanup] Could not delete file ${data.media_path}: ${storageErr.message}`);
              }
            }

            // Delete the message document
            await msgDoc.ref.delete();
            deletedCount++;
            console.log(`[Cleanup] Deleted expired doc message ${msgDoc.id} from chat ${chatDoc.id}`);
          } catch (delErr) {
            errorCount++;
            console.error(`[Cleanup] Error deleting message ${msgDoc.id}: ${delErr}`);
          }
        }
      } catch (chatErr) {
        errorCount++;
        console.error(`[Cleanup] Error processing chat ${chatDoc.id}: ${chatErr}`);
      }
    }

    console.log(`[Cleanup] Done. Deleted: ${deletedCount}, Errors: ${errorCount}`);
  }
);

exports.enrollWorkerFace = onCall(async (request) => {
  const data = request.data || {};
  const workerId = requireString(data.worker_id || data.workerId, "worker_id");
  const projectId = requireString(data.project_id || data.projectId, "project_id");
  const photoUrls = Array.isArray(data.photo_urls || data.photoUrls)
    ? (data.photo_urls || data.photoUrls)
    : [];

  // TODO(backend): upload refs to Firebase Storage and call AWS IndexFaces.
  console.log("[Timesheet] enrollWorkerFace mock", {
    workerId,
    projectId,
    photoCount: photoUrls.length,
    awsRegion: AWS_REKOGNITION_REGION,
  });

  return {
    success: true,
    face_id: `mock_${workerId}`,
    project_id: projectId,
  };
});

exports.matchAttendance = onCall(async (request) => {
  const data = request.data || {};
  const projectId = requireString(data.project_id || data.projectId, "project_id");
  const taskId = requireString(data.task_id || data.taskId, "task_id");
  const cropUrl = requireString(data.crop_url || data.cropUrl, "crop_url");
  const eventName = data.event || "checkIn";
  const hash = stableHash(`${projectId}|${taskId}|${cropUrl}|${eventName}`);
  const bucket = hash % 3;
  const similarity = bucket === 0 ? 97.4 : bucket === 1 ? 92.3 : 77.8;
  const result = bucket === 0
    ? "matched"
    : bucket === 1
      ? "needs_confirmation"
      : "no_match";

  // TODO(backend): call AWS SearchFacesByImage, compute geofence, and write
  // attendance through the Odoo bridge.
  return {
    result,
    similarity,
    worker_id: result === "no_match" ? null : `worker_${hash % 1000}`,
    attendance_id: result === "no_match" ? null : `att_${hash}`,
    outside_geofence: hash % 5 === 0,
    task_membership: hash % 7 !== 0,
    needs_confirmation: result === "needs_confirmation",
  };
});

exports.deleteWorkerFace = onCall(async (request) => {
  const data = request.data || {};
  const workerId = requireString(data.worker_id || data.workerId, "worker_id");
  const projectId = requireString(data.project_id || data.projectId, "project_id");

  // TODO(backend): call AWS DeleteFaces for this project's collection.
  console.log("[Timesheet] deleteWorkerFace mock", {
    workerId,
    projectId,
    awsRegion: AWS_REKOGNITION_REGION,
  });

  return {
    success: true,
    worker_id: workerId,
    project_id: projectId,
  };
});

function requireString(value, fieldName) {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${fieldName} is required`);
  }
  return value.trim();
}

function stableHash(value) {
  let hash = 0;
  for (let i = 0; i < value.length; i++) {
    hash = ((hash << 5) - hash) + value.charCodeAt(i);
    hash |= 0;
  }
  return Math.abs(hash);
}
