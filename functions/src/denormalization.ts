/**
 * Denormalization sync: when a user renames themselves or changes avatar,
 * propagate to their recent posts so the feed stays fresh.
 *
 * Comments are intentionally left with the old identity (like Instagram);
 * they show the fresh identity the next time the user comments.
 */
import { getFirestore } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const db = () => getFirestore();

/** Most recent posts to rewrite per profile change. */
const MAX_POSTS_TO_SYNC = 400;
const BATCH_SIZE = 400;

export const onUserProfileUpdated = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const nameChanged = before.displayName !== after.displayName;
    const photoChanged = before.photoUrl !== after.photoUrl;
    if (!nameChanged && !photoChanged) return;

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
