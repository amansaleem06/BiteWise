/**
 * Keep the public profile projection and recent post identity in sync with the
 * private users/{uid} source document.
 */
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentWritten } from "firebase-functions/v2/firestore";

const db = () => getFirestore();

/** Most recent posts to rewrite per profile change. */
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

export const onUserProfileUpdated = onDocumentWritten(
  "users/{uid}",
  async (event) => {
    const before = event.data?.before.exists
      ? event.data.before.data()
      : undefined;
    const after = event.data?.after.exists
      ? event.data.after.data()
      : undefined;
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

    for (let i = 0; i < posts.docs.length; i += BATCH_SIZE) {
      const batch = db().batch();
      posts.docs
        .slice(i, i + BATCH_SIZE)
        .forEach((doc) => batch.update(doc.ref, updates));
      await batch.commit();
    }
  },
);
