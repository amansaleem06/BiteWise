/**
 * Notification fan-out + push delivery.
 *
 * Notification docs live at users/{uid}/notifications/{id} and are created
 * exclusively here (clients have read/mark-read access only). A separate
 * trigger delivers each new notification via FCM and prunes dead tokens.
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";

const db = () => getFirestore();

type NotificationType = "like" | "comment" | "follow";

interface NotificationPayload {
  type: NotificationType;
  actorId: string;
  postId?: string;
  postMediaUrl?: string;
  text?: string;
}

async function createNotification(
  recipientUid: string,
  payload: NotificationPayload,
): Promise<void> {
  if (recipientUid === payload.actorId) return; // never notify yourself

  const actorSnap = await db().doc(`users/${payload.actorId}`).get();
  const actor = actorSnap.data() ?? {};

  await db().collection(`users/${recipientUid}/notifications`).add({
    type: payload.type,
    actorId: payload.actorId,
    actorName: actor.displayName ?? "Someone",
    actorPhotoUrl: actor.photoUrl ?? null,
    postId: payload.postId ?? null,
    postMediaUrl: payload.postMediaUrl ?? null,
    text: payload.text ?? null,
    read: false,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function firstMediaUrl(post: FirebaseFirestore.DocumentData): string | undefined {
  const media = Array.isArray(post.media) ? post.media : [];
  const first = media[0];
  return first && typeof first.url === "string" ? first.url : undefined;
}

/** Like → notify post author. */
export const onLikeNotify = onDocumentCreated(
  "posts/{postId}/likes/{uid}",
  async (event) => {
    const postSnap = await db().doc(`posts/${event.params.postId}`).get();
    const post = postSnap.data();
    if (!post?.authorId) return;
    await createNotification(post.authorId, {
      type: "like",
      actorId: event.params.uid,
      postId: event.params.postId,
      postMediaUrl: firstMediaUrl(post),
    });
  },
);

/** Comment → notify post author. */
export const onCommentNotify = onDocumentCreated(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const comment = event.data?.data();
    if (!comment?.authorId) return;
    const postSnap = await db().doc(`posts/${event.params.postId}`).get();
    const post = postSnap.data();
    if (!post?.authorId) return;
    await createNotification(post.authorId, {
      type: "comment",
      actorId: comment.authorId,
      postId: event.params.postId,
      postMediaUrl: firstMediaUrl(post),
      text:
        typeof comment.text === "string" ? comment.text.slice(0, 120) : "",
    });
  },
);

/** Follow → notify the followed user. */
export const onFollowNotify = onDocumentCreated(
  "users/{uid}/following/{targetUid}",
  async (event) => {
    await createNotification(event.params.targetUid, {
      type: "follow",
      actorId: event.params.uid,
    });
  },
);

/** New notification doc → FCM push to all of the recipient's devices. */
export const onNotificationPush = onDocumentCreated(
  "users/{uid}/notifications/{notificationId}",
  async (event) => {
    const n = event.data?.data();
    if (!n) return;

    const tokensSnap = await db()
      .collection(`users/${event.params.uid}/tokens`)
      .get();
    if (tokensSnap.empty) return;
    const tokens = tokensSnap.docs.map((d) => d.id);

    const title = "BiteWise";
    const body =
      n.type === "like"
        ? `${n.actorName} liked your post`
        : n.type === "comment"
          ? `${n.actorName} commented: ${n.text ?? ""}`
          : `${n.actorName} started following you`;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title, body },
      data: {
        type: String(n.type),
        postId: String(n.postId ?? ""),
        actorId: String(n.actorId ?? ""),
      },
      android: { notification: { channelId: "bitewise_default" } },
      apns: { payload: { aps: { sound: "default" } } },
    });

    // Prune tokens that are no longer valid.
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
        batch.delete(db().doc(`users/${event.params.uid}/tokens/${t}`)),
      );
      await batch.commit();
    }
  },
);
