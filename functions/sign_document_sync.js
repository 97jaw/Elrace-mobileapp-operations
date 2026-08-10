const { onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

/**
 * When a signable_doc message finishes signing (or advances), sync the
 * owner's personal signature_documents library and notify the requester.
 *
 * Fixes: signer B cannot write users/{A}/signature_documents under owner-only
 * rules — Admin SDK bypasses that. Also sends FCM (create-only chat push
 * never fires on message update).
 */
exports.onSignableDocumentUpdated = onDocumentUpdated(
  {
    document: "chats/{chatId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const db = getFirestore();
    const messaging = getMessaging();

    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;
    if (after.type !== "signable_doc") return;

    const beforeStatus = before.sign_status || "";
    const afterStatus = after.sign_status || "";
    const beforeSignedUrl = before.signed_pdf_url || "";
    const afterSignedUrl = after.signed_pdf_url || "";
    const beforeIndex = before.current_signer_index ?? 0;
    const afterIndex = after.current_signer_index ?? 0;

    const becameSigned =
      afterStatus === "signed" && beforeStatus !== "signed";
    const advancedChain =
      afterStatus === "pending" &&
      (afterSignedUrl !== beforeSignedUrl || afterIndex !== beforeIndex);

    if (!becameSigned && !advancedChain) return;

    const chatId = event.params.chatId;
    const messageId = event.params.messageId;
    const ownerUid = after.sender_id;
    const signerUid = after.signed_by || "";
    const linkedDocId = after.signature_document_id;
    const signedUrl = after.signed_pdf_url || after.media_url || "";

    // ── Sync personal library (Admin SDK) ─────────────────────
    if (ownerUid && linkedDocId) {
      try {
        const personalRef = db
          .collection("users")
          .doc(ownerUid)
          .collection("signature_documents")
          .doc(linkedDocId);

        if (becameSigned) {
          await personalRef.set(
            {
              status: "signed",
              signed_pdf_url: signedUrl,
              file_url: signedUrl || undefined,
              signed_by: signerUid || null,
              signed_at: after.signed_at || new Date(),
              updated_at: new Date(),
            },
            { merge: true }
          );
          console.log(
            `Synced personal doc ${linkedDocId} → signed (owner=${ownerUid})`
          );
        } else if (advancedChain) {
          const nextUid = after.current_signer_uid || "";
          const names = after.signer_names || [];
          const nextName =
            names[afterIndex] || after.recipient_name || "Colleague";
          await personalRef.set(
            {
              status: "pending_other",
              file_url: signedUrl || undefined,
              recipient_uid: nextUid || null,
              recipient_name: nextName,
              current_signer_index: afterIndex,
              updated_at: new Date(),
            },
            { merge: true }
          );
          console.log(
            `Synced personal doc ${linkedDocId} → pending_other idx=${afterIndex}`
          );
        }
      } catch (e) {
        console.error(`Personal signature doc sync failed: ${e}`);
      }
    }

    // ── Notify requester when fully signed ────────────────────
    if (!becameSigned) return;
    if (!ownerUid || ownerUid === signerUid) return;

    let signerName = "Someone";
    try {
      if (signerUid) {
        const signerDoc = await db.collection("users").doc(signerUid).get();
        if (signerDoc.exists) {
          const d = signerDoc.data() || {};
          signerName = d.name || d.display_name || "Someone";
        }
      }
    } catch (e) {
      console.log(`Could not resolve signer name: ${e}`);
    }

    const fileName = after.file_name || "Document";
    const title = "Document signed";
    const body = `${signerName} signed “${fileName}”`;

    try {
      const userDoc = await db.collection("users").doc(ownerUid).get();
      if (userDoc.exists && userDoc.data()?.chat_notifications_muted === true) {
        console.log(`Skip notify ${ownerUid}: global muted`);
        return;
      }

      const tokensSnap = await db
        .collection("users")
        .doc(ownerUid)
        .collection("fcm_tokens")
        .get();
      if (tokensSnap.empty) {
        console.log(`No FCM tokens for owner ${ownerUid}`);
        return;
      }

      const messages = tokensSnap.docs.map((tokenDoc) => ({
        token: tokenDoc.id,
        notification: { title, body },
        data: {
          type: "document_signed",
          category: "document_signed",
          chat_id: chatId,
          message_id: messageId,
          sender_id: signerUid,
          sender_name: signerName,
          file_name: fileName,
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
        `Document-signed notify owner=${ownerUid}: ${ok}/${messages.length}`
      );
    } catch (e) {
      console.error(`Document-signed notification failed: ${e}`);
    }
  }
);
