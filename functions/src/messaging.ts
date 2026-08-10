/**
 * Chat push delivery: notify the recipient of a new message via FCM.
 * Messages deliberately do NOT create notification-feed docs — they get
 * push + the Messages tab unread state instead.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

const db = () => getFirestore();

export const onChatMessagePush = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message?.senderId) return;

    const chatSnap = await db().doc(`chats/${event.params.chatId}`).get();
    const chat = chatSnap.data();
    if (!chat) return;

    const participants: string[] = Array.isArray(chat.participants)
      ? chat.participants
      : [];
    const recipient = participants.find((p) => p !== message.senderId);
    if (!recipient) return;

    const info = chat.participantInfo ?? {};
    const senderName = info[message.senderId]?.name ?? "New message";

    const tokensSnap = await db()
      .collection(`users/${recipient}/tokens`)
      .get();
    if (tokensSnap.empty) return;
    const tokens = tokensSnap.docs.map((d) => d.id);

    const body =
      message.type === "image"
        ? "📷 Photo"
        : typeof message.text === "string"
          ? message.text.slice(0, 120)
          : "";

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: senderName, body },
      data: { type: "message", chatId: event.params.chatId },
      android: { notification: { channelId: "bitewise_messages" } },
      apns: { payload: { aps: { sound: "default" } } },
    });

    const dead: string[] = [];
    response.responses.forEach((r, i) => {
      const code = r.error?.code ?? "";
      if (
        code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-registration-token"
      ) {
        dead.push(tokens[i]);
      }
    });
    if (dead.length > 0) {
      const batch = db().batch();
      dead.forEach((t) =>
        batch.delete(db().doc(`users/${recipient}/tokens/${t}`)),
      );
      await batch.commit();
    }
  },
);
