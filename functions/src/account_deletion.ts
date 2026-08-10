/**
 * Cascade cleanup when a Firebase Auth user is deleted.
 *
 * The client deletes Auth + best-effort personal Firestore data. This trigger
 * finishes server-side cleanup clients cannot safely do (posts, storage, etc.).
 */
import { getFirestore, Query } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as functions from "firebase-functions/v1";

const db = () => getFirestore();

async function deleteQueryBatch(
  query: Query,
  batchSize = 300,
): Promise<void> {
  const snap = await query.limit(batchSize).get();
  if (snap.empty) return;

  const batch = db().batch();
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();

  if (snap.size >= batchSize) {
    await deleteQueryBatch(query, batchSize);
  }
}

async function deleteSubcollections(uid: string): Promise<void> {
  const userRef = db().doc(`users/${uid}`);
  const names = [
    "tokens",
    "bookmarks",
    "notifications",
    "following",
    "followers",
  ];
  for (const name of names) {
    await deleteQueryBatch(userRef.collection(name));
  }
  const userSnap = await userRef.get();
  if (userSnap.exists) {
    await userRef.delete();
  }
}

async function anonymizePosts(uid: string): Promise<void> {
  const posts = await db()
    .collection("posts")
    .where("authorId", "==", uid)
    .limit(300)
    .get();

  if (posts.empty) return;

  const batch = db().batch();
  for (const doc of posts.docs) {
    batch.update(doc.ref, {
      authorId: "deleted",
      authorName: "Deleted user",
      authorPhotoUrl: null,
      caption: "",
    });
  }
  await batch.commit();

  if (posts.size >= 300) {
    await anonymizePosts(uid);
  }
}

async function deleteStoragePrefix(uid: string): Promise<void> {
  try {
    const bucket = getStorage().bucket();
    await bucket.deleteFiles({ prefix: `users/${uid}/` });
    await bucket.deleteFiles({ prefix: `avatars/${uid}/` });
  } catch {
    // Prefix may be empty — ignore.
  }
}

export const onAuthUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  await Promise.all([
    deleteSubcollections(uid),
    anonymizePosts(uid),
    deleteStoragePrefix(uid),
  ]);
});
