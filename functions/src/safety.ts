import { getFirestore } from "firebase-admin/firestore";

export async function isBlocked(a: string, b: string): Promise<boolean> {
  if (!a || !b || a === b) return false;
  const db = getFirestore();
  const docs = await db.getAll(db.doc('users/' + a + '/blocked/' + b), db.doc('users/' + b + '/blocked/' + a));
  return docs.some(doc => doc.exists);
}
