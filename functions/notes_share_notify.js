const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

/**
 * Notify the recipient when a note is shared with them
 * (users/{uid}/shared_note_refs/{noteId} created).
 */
exports.onNoteShared = onDocumentCreated(
  {
    document: "users/{uid}/shared_note_refs/{noteId}",
    region: "us-central1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() || {};
    const recipientUid = event.params.uid;
    const noteId = event.params.noteId;
    const ownerId = data.ownerId || data.owner_id || "";
    const noteTitle = (data.title || "a note").toString();

    if (!recipientUid) return;

    const db = getFirestore();
    const messaging = getMessaging();

    let ownerName = "Someone";
    try {
      if (ownerId) {
        const ownerDoc = await db.collection("users").doc(ownerId).get();
        if (ownerDoc.exists) {
          const d = ownerDoc.data() || {};
          ownerName = d.name || d.display_name || "Someone";
        }
      }
    } catch (e) {
      console.log(`Could not resolve note owner name: ${e}`);
    }

    const title = "Note shared with you";
    const body = `${ownerName} shared “${noteTitle}”`;

    try {
      const userDoc = await db.collection("users").doc(recipientUid).get();
      if (userDoc.exists && userDoc.data()?.chat_notifications_muted === true) {
        console.log(`Skip note-share notify ${recipientUid}: muted`);
        return;
      }

      const tokensSnap = await db
        .collection("users")
        .doc(recipientUid)
        .collection("fcm_tokens")
        .get();
      if (tokensSnap.empty) {
        console.log(`No FCM tokens for note share recipient ${recipientUid}`);
        return;
      }

      const messages = tokensSnap.docs.map((tokenDoc) => ({
        token: tokenDoc.id,
        notification: { title, body },
        data: {
          type: "note_shared",
          category: "note_shared",
          note_id: noteId,
          owner_id: ownerId,
          note_title: noteTitle,
          sender_id: ownerId,
          sender_name: ownerName,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
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
      const ok = results.filter((r) => r.status === "fulfilled").length;
      console.log(
        `Note-shared notify ${recipientUid}: ${ok}/${messages.length}`
      );
    } catch (e) {
      console.error(`Note-shared notification failed: ${e}`);
    }
  }
);
