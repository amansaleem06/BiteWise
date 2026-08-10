/**
 * Reservation notifications:
 *  - status changes (confirmed/rejected/completed) → notify the diner
 *  - new requests → notify the restaurant owner (once claiming exists)
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";

const db = () => getFirestore();

function formatWhen(dateTime: FirebaseFirestore.Timestamp): string {
  return dateTime.toDate().toLocaleString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export const onReservationStatusChanged = onDocumentUpdated(
  "reservations/{reservationId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after || before.status === after.status) return;
    // Diner-initiated cancellations don't need a self-notification.
    if (after.status === "cancelled") return;
    if (!after.userId) return;

    const verb =
      after.status === "confirmed"
        ? "confirmed"
        : after.status === "rejected"
          ? "declined"
          : after.status === "completed"
            ? "completed"
            : "updated";

    const when = after.dateTime ? ` for ${formatWhen(after.dateTime)}` : "";

    await db().collection(`users/${after.userId}/notifications`).add({
      type: "reservation",
      actorId: after.restaurantId ?? "",
      actorName: after.restaurantName ?? "Restaurant",
      actorPhotoUrl: after.restaurantLogoUrl ?? null,
      postId: null,
      postMediaUrl: null,
      text: `${verb} your reservation${when}`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  },
);

export const onReservationRequested = onDocumentCreated(
  "reservations/{reservationId}",
  async (event) => {
    const r = event.data?.data();
    if (!r?.restaurantId) return;

    const restaurantSnap = await db()
      .doc(`restaurants/${r.restaurantId}`)
      .get();
    const ownerId = restaurantSnap.data()?.ownerId;
    if (!ownerId || ownerId === r.userId) return;

    await db().collection(`users/${ownerId}/notifications`).add({
      type: "reservation",
      actorId: r.userId ?? "",
      actorName: r.userName ?? "A guest",
      actorPhotoUrl: r.userPhotoUrl ?? null,
      postId: null,
      postMediaUrl: null,
      text: `requested a table for ${r.partySize ?? "?"}${
        r.dateTime ? ` on ${formatWhen(r.dateTime)}` : ""
      }`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  },
);
