/**
 * Keep the public profile projection and recent post identity in sync with the
 * private users/{uid} source document.
 */
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

const db = () => getFirestore();

/** Maximum copied references inspected per collection and profile change. */
const MAX_POSTS_TO_SYNC = 400;
const BATCH_SIZE = 400;

const PUBLIC_PROFILE_FIELDS = [
  "displayName",
  "displayNameLower",
  "username",
  "usernameLower",
  "photoUrl",
  "bio",
  "role",
  "businessName",
  "businessVerificationStatus",
  "ownedRestaurantId",
  "messagePrivacy",
  "followerCount",
  "followingCount",
  "postCount",
  "suspended",
  "createdAt",
  "updatedAt",
] as const;

function publicProfile(data: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const field of PUBLIC_PROFILE_FIELDS) {
    if (data[field] !== undefined) result[field] = data[field];
  }
  return result;
}

async function updateDocuments(
  documents: FirebaseFirestore.QueryDocumentSnapshot[],
  updates: Record<string, unknown>,
): Promise<void> {
  for (let i = 0; i < documents.length; i += BATCH_SIZE) {
    const batch = db().batch();
    documents
      .slice(i, i + BATCH_SIZE)
      .forEach((doc) => batch.update(doc.ref, updates));
    await batch.commit();
  }
}

function ownedAvatarPath(url: unknown, uid: string): string | undefined {
  if (typeof url !== "string" || !url) return undefined;
  try {
    const path = decodeURIComponent(new URL(url).pathname.split("/o/")[1] ?? "");
    return path.startsWith(`avatars/${uid}/`) ? path : undefined;
  } catch {
    return undefined;
  }
}

export const onUserProfileUpdated = onDocumentWritten(
  "users/{uid}",
  async (event) => {
    const before = event.data?.before.exists
      ? event.data.before.data()
      : undefined;
    const profileRef = db().doc(`users/${event.params.uid}`);
    for (let attempt = 0; attempt < 3; attempt++) {
      // Events can arrive out of order during quick A -> B -> C replacements.
      // Always project the current profile so an older event cannot restore B.
      const current = await profileRef.get();
      const after = current.exists ? current.data() : undefined;
      const publicRef = db().doc(`publicProfiles/${event.params.uid}`);

      if (!after) {
        await publicRef.delete().catch(() => undefined);
        return;
      }

      // Replace instead of merge so a field removed from the private profile
      // cannot survive indefinitely in its public projection.
      await publicRef.set(publicProfile(after));

      const nameChanged = before?.displayName !== after.displayName;
      const photoChanged = before?.photoUrl !== after.photoUrl;
      if (!before || (!nameChanged && !photoChanged)) return;

      const updates: Record<string, unknown> = {};
      if (nameChanged) updates.authorName = after.displayName ?? "";
      if (photoChanged) updates.authorPhotoUrl = after.photoUrl ?? null;

      const posts = await db()
        .collection("posts")
        .where("authorId", "==", event.params.uid)
        .orderBy("createdAt", "desc")
        .limit(MAX_POSTS_TO_SYNC)
        .get();
      let canDeletePreviousAvatar = posts.size < MAX_POSTS_TO_SYNC;

      // Restaurant-page content keeps the restaurant logo and name.
      await updateDocuments(
        posts.docs.filter((doc) => !doc.data().asRestaurantId),
        updates,
      );

      const stories = await db()
        .collection("stories")
        .where("authorId", "==", event.params.uid)
        .limit(MAX_POSTS_TO_SYNC)
        .get();
      canDeletePreviousAvatar &&= stories.size < MAX_POSTS_TO_SYNC;
      await updateDocuments(
        stories.docs.filter((doc) => !doc.data().asRestaurantId),
        updates,
      );

      const comments = await db()
        .collectionGroup("comments")
        .where("authorId", "==", event.params.uid)
        .limit(MAX_POSTS_TO_SYNC)
        .get();
      canDeletePreviousAvatar &&= comments.size < MAX_POSTS_TO_SYNC;
      // Older story comments do not record asRestaurantId. Keep restaurant
      // page identity intact by updating only comments under the user's name.
      const personalComments = comments.docs.filter(
        (doc) => !doc.data().asRestaurantId &&
          doc.data().authorName === before.displayName,
      );
      if (comments.docs.some((doc) =>
        !personalComments.includes(doc) &&
          doc.data().authorPhotoUrl === before.photoUrl)) {
        canDeletePreviousAvatar = false;
      }
      await updateDocuments(
        personalComments,
        updates,
      );

      const notifications = await db()
        .collectionGroup("notifications")
        .where("actorId", "==", event.params.uid)
        .limit(MAX_POSTS_TO_SYNC)
        .get();
      canDeletePreviousAvatar &&= notifications.size < MAX_POSTS_TO_SYNC;
      const notificationUpdates: Record<string, unknown> = {};
      if (nameChanged) notificationUpdates.actorName = after.displayName ?? "";
      if (photoChanged) notificationUpdates.actorPhotoUrl = after.photoUrl ?? null;
      await updateDocuments(notifications.docs, notificationUpdates);

      const chats = await db()
        .collection("chats")
        .where("participants", "array-contains", event.params.uid)
        .limit(MAX_POSTS_TO_SYNC)
        .get();
      canDeletePreviousAvatar &&= chats.size < MAX_POSTS_TO_SYNC;
      const chatUpdates: Record<string, unknown> = {};
      if (nameChanged) {
        chatUpdates[`participantInfo.${event.params.uid}.name`] =
          after.displayName ?? "";
      }
      if (photoChanged) {
        chatUpdates[`participantInfo.${event.params.uid}.photoUrl`] =
          after.photoUrl ?? null;
      }
      await updateDocuments(chats.docs, chatUpdates);

      const reservations = await db()
        .collection("reservations")
        .where("userId", "==", event.params.uid)
        .limit(MAX_POSTS_TO_SYNC)
        .get();
      canDeletePreviousAvatar &&= reservations.size < MAX_POSTS_TO_SYNC;
      const reservationUpdates: Record<string, unknown> = {};
      if (nameChanged) reservationUpdates.userName = after.displayName ?? "";
      if (photoChanged) reservationUpdates.userPhotoUrl = after.photoUrl ?? null;
      await updateDocuments(reservations.docs, reservationUpdates);

      // If the user replaced the photo again while these writes ran, repeat
      // with the current value before deleting or returning.
      const latest = await profileRef.get();
      if (latest.data()?.photoUrl !== after.photoUrl ||
          latest.data()?.displayName !== after.displayName) {
        continue;
      }

      // Delete only a superseded object owned by this account, and only after
      // all copied references above have been updated successfully.
      if (photoChanged) {
        const previousPath = ownedAvatarPath(before?.photoUrl, event.params.uid);
        const nextPath = ownedAvatarPath(after.photoUrl, event.params.uid);
        if (canDeletePreviousAvatar && previousPath && previousPath !== nextPath) {
          await getStorage()
            .bucket()
            .file(previousPath)
            .delete({ ignoreNotFound: true });
        } else if (!canDeletePreviousAvatar && previousPath) {
          console.warn("Avatar cleanup skipped: profile references exceeded sync limit", {
            uid: event.params.uid,
            previousPath,
          });
        }
      }
      return;
    }
    console.warn("Profile sync changed repeatedly; awaiting the latest event", {
      uid: event.params.uid,
    });
  },
);
