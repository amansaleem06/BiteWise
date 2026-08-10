/**
 * Trending score: engagement weighted by freshness, recomputed hourly for
 * posts from the last 7 days. Older posts decay to 0 and drop out of the
 * Trending tab naturally.
 *
 *   score = (likes * 3 + comments * 2) * exp(-ageHours / 48)
 */
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

const db = () => getFirestore();

const WINDOW_DAYS = 7;
const BATCH_SIZE = 400;

export const computeTrendingScores = onSchedule(
  "every 60 minutes",
  async () => {
    const cutoff = Timestamp.fromMillis(
      Date.now() - WINDOW_DAYS * 24 * 60 * 60 * 1000,
    );

    const posts = await db()
      .collection("posts")
      .where("createdAt", ">=", cutoff)
      .get();

    const now = Date.now();
    let batch = db().batch();
    let pending = 0;

    for (const doc of posts.docs) {
      const d = doc.data();
      const likes = typeof d.likeCount === "number" ? d.likeCount : 0;
      const comments = typeof d.commentCount === "number" ? d.commentCount : 0;
      const createdAt: Timestamp | undefined = d.createdAt;
      const ageHours = createdAt
        ? (now - createdAt.toMillis()) / 3_600_000
        : WINDOW_DAYS * 24;

      const score =
        (likes * 3 + comments * 2) * Math.exp(-ageHours / 48);
      const rounded = Math.round(score * 1000) / 1000;

      if (d.trendingScore !== rounded) {
        batch.update(doc.ref, { trendingScore: rounded });
        pending++;
        if (pending >= BATCH_SIZE) {
          await batch.commit();
          batch = db().batch();
          pending = 0;
        }
      }
    }
    if (pending > 0) await batch.commit();
  },
);
