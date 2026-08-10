/**
 * BiteWise Cloud Functions entry point.
 *
 * Modules:
 *  - counters:        all denormalized counts (likes, comments, follows,
 *                     post counts, restaurant rating aggregates)
 *  - denormalization: profile identity sync to recent posts
 *  - trending:        hourly time-decayed trending scores
 */
import { initializeApp } from "firebase-admin/app";

initializeApp();

export {
  onPostLikeWritten,
  onPostCommentWritten,
  onRestaurantFollowerWritten,
  onUserFollowingWritten,
  onPostCreatedFn,
  onPostDeletedFn,
} from "./counters";

export { onUserProfileUpdated } from "./denormalization";

export { computeTrendingScores } from "./trending";

export {
  onLikeNotify,
  onCommentNotify,
  onFollowNotify,
  onNotificationPush,
} from "./notifications";

export { onChatMessagePush } from "./messaging";

export {
  onReservationStatusChanged,
  onReservationRequested,
} from "./reservations";

export { onAuthUserDeleted } from "./account_deletion";
