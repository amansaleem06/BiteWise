/**
 * Counter maintenance — the single source of truth for all denormalized
 * counts. Clients only write edge documents (likes, comments, follows);
 * these triggers keep the aggregates consistent.
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";

const db = () => getFirestore();

/** posts/{postId}/likes/{uid} → posts.likeCount */
export const onPostLikeWritten = onDocumentWritten(
  "posts/{postId}/likes/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    if (before === after) return;
    await db()
      .doc(`posts/${event.params.postId}`)
      .update({ likeCount: FieldValue.increment(after ? 1 : -1) })
      .catch(() => undefined); // post may have been deleted
  },
);

/** posts/{postId}/comments/{commentId} → posts.commentCount */
export const onPostCommentWritten = onDocumentWritten(
  "posts/{postId}/comments/{commentId}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    if (before === after) return;
    await db()
      .doc(`posts/${event.params.postId}`)
      .update({ commentCount: FieldValue.increment(after ? 1 : -1) })
      .catch(() => undefined);
  },
);

/** restaurants/{restaurantId}/followers/{uid} → restaurants.followerCount */
export const onRestaurantFollowerWritten = onDocumentWritten(
  "restaurants/{restaurantId}/followers/{uid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    if (before === after) return;
    await db()
      .doc(`restaurants/${event.params.restaurantId}`)
      .update({ followerCount: FieldValue.increment(after ? 1 : -1) })
      .catch(() => undefined);
  },
);

/**
 * users/{uid}/following/{targetUid} is the canonical follow edge the client
 * writes. This trigger mirrors the reverse edge (followers) and maintains
 * both counters, making a follow a single client write.
 */
export const onUserFollowingWritten = onDocumentWritten(
  "users/{uid}/following/{targetUid}",
  async (event) => {
    const before = event.data?.before.exists ?? false;
    const after = event.data?.after.exists ?? false;
    if (before === after) return;

    const { uid, targetUid } = event.params;
    const batch = db().batch();
    const followerRef = db().doc(`users/${targetUid}/followers/${uid}`);

    if (after) {
      batch.set(followerRef, { createdAt: FieldValue.serverTimestamp() });
      batch.update(db().doc(`users/${uid}`), {
        followingCount: FieldValue.increment(1),
      });
      batch.update(db().doc(`users/${targetUid}`), {
        followerCount: FieldValue.increment(1),
      });
    } else {
      batch.delete(followerRef);
      batch.update(db().doc(`users/${uid}`), {
        followingCount: FieldValue.increment(-1),
      });
      batch.update(db().doc(`users/${targetUid}`), {
        followerCount: FieldValue.increment(-1),
      });
    }
    await batch.commit().catch(() => undefined);
  },
);

/**
 * Post lifecycle: author postCount, restaurant postCount and rating
 * aggregates (ratingSum / ratingCount / ratingAvg).
 */
export const onPostCreatedFn = onDocumentCreated(
  "posts/{postId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const batch = db().batch();
    if (data.authorId) {
      batch.update(db().doc(`users/${data.authorId}`), {
        postCount: FieldValue.increment(1),
      });
    }
    if (data.restaurantId) {
      const updates: Record<string, unknown> = {
        postCount: FieldValue.increment(1),
      };
      if (typeof data.rating === "number") {
        updates.ratingSum = FieldValue.increment(data.rating);
        updates.ratingCount = FieldValue.increment(1);
      }
      batch.update(db().doc(`restaurants/${data.restaurantId}`), updates);
    }
    await batch.commit().catch(() => undefined);

    // Recompute ratingAvg after the increment lands.
    if (data.restaurantId && typeof data.rating === "number") {
      await recomputeRatingAvg(data.restaurantId);
    }
  },
);

export const onPostDeletedFn = onDocumentDeleted(
  "posts/{postId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const batch = db().batch();
    if (data.authorId) {
      batch.update(db().doc(`users/${data.authorId}`), {
        postCount: FieldValue.increment(-1),
      });
    }
    if (data.restaurantId) {
      const updates: Record<string, unknown> = {
        postCount: FieldValue.increment(-1),
      };
      if (typeof data.rating === "number") {
        updates.ratingSum = FieldValue.increment(-data.rating);
        updates.ratingCount = FieldValue.increment(-1);
      }
      batch.update(db().doc(`restaurants/${data.restaurantId}`), updates);
    }
    await batch.commit().catch(() => undefined);

    if (data.restaurantId && typeof data.rating === "number") {
      await recomputeRatingAvg(data.restaurantId);
    }

    // Clean up subcollections (likes + comments) in pages.
    const postRef = db().doc(`posts/${event.params.postId}`);
    for (const sub of ["likes", "comments"]) {
      // eslint-disable-next-line no-constant-condition
      while (true) {
        const page = await postRef.collection(sub).limit(200).get();
        if (page.empty) break;
        const cleanup = db().batch();
        page.docs.forEach((d) => cleanup.delete(d.ref));
        await cleanup.commit();
        if (page.size < 200) break;
      }
    }
  },
);

async function recomputeRatingAvg(restaurantId: string): Promise<void> {
  const ref = db().doc(`restaurants/${restaurantId}`);
  const snap = await ref.get();
  if (!snap.exists) return;
  const d = snap.data() ?? {};
  const count = typeof d.ratingCount === "number" ? d.ratingCount : 0;
  const sum = typeof d.ratingSum === "number" ? d.ratingSum : 0;
  await ref.update({
    ratingAvg: count > 0 ? Math.round((sum / count) * 100) / 100 : null,
  });
}
