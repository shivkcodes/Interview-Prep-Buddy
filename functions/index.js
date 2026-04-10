const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendPeerMessageNotification = onDocumentCreated(
  "peer_chats/{chatId}/messages/{messageId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.log("No message data found.");
      return;
    }

    const messageData = snapshot.data();
    const chatId = event.params.chatId;

    const senderId = messageData.senderId || "";
    const senderName = messageData.senderName || "New message";
    const text = messageData.text || "You received a new message";

    const chatDoc = await admin
      .firestore()
      .collection("peer_chats")
      .doc(chatId)
      .get();

    if (!chatDoc.exists) {
      logger.log("Chat document not found.");
      return;
    }

    const chatData = chatDoc.data() || {};
    const participants = Array.isArray(chatData.participants)
      ? chatData.participants
      : [];

    const receiverIds = participants.filter((id) => id !== senderId);

    if (receiverIds.length === 0) {
      logger.log("No receiver found.");
      return;
    }

    for (const receiverId of receiverIds) {
      const profileDoc = await admin
        .firestore()
        .collection("profiles")
        .doc(receiverId)
        .get();

      if (!profileDoc.exists) {
        logger.log(`Profile not found for ${receiverId}`);
        continue;
      }

      const profileData = profileDoc.data() || {};
      const tokens = Array.isArray(profileData.fcmTokens)
        ? profileData.fcmTokens.filter(Boolean)
        : [];

      if (tokens.length === 0) {
        logger.log(`No FCM tokens found for ${receiverId}`);
        continue;
      }

      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: senderName,
          body: text,
        },
        data: {
          chatId,
          senderId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "prep_buddy_messages",
          },
        },
      });

      const invalidTokens = [];
      response.responses.forEach((result, index) => {
        if (!result.success) {
          const errorCode = result.error?.code || "";
          if (
            errorCode.includes("registration-token-not-registered") ||
            errorCode.includes("invalid-registration-token")
          ) {
            invalidTokens.push(tokens[index]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        await admin
          .firestore()
          .collection("profiles")
          .doc(receiverId)
          .set(
            {
              fcmTokens: admin.firestore.FieldValue.arrayRemove(
                ...invalidTokens,
              ),
            },
            { merge: true },
          );
      }
    }
  },
);
