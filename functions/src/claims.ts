/**
 * Restaurant claim review:
 *   Clients may only create pending claimRequests.
 *   When support sets status = "approved" in the console, this trigger
 *   grants Verified Owner and rejects competing requests.
 */
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";

const db = () => getFirestore();

export const onClaimRequestApproved = onDocumentUpdated(
  "restaurants/{restaurantId}/claimRequests/{uid}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after || after.status !== "approved") return;
    if (before?.status === "approved") return;

    const restaurantId = event.params.restaurantId;
    const uid = event.params.uid;
    const restRef = db().doc(`restaurants/${restaurantId}`);
    const restSnap = await restRef.get();
    const rest = restSnap.data() ?? {};
    const existingOwner = rest.ownerId as string | undefined;
    const alreadyClaimed = rest.claimed === true || rest.claimStatus === "claimed";

    if (alreadyClaimed && existingOwner && existingOwner !== uid) {
      await event.data?.after.ref.update({
        status: "rejected",
        rejectReason: "already_claimed",
        updatedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    await restRef.update({
      ownerId: uid,
      claimed: true,
      claimStatus: "claimed",
      updatedAt: FieldValue.serverTimestamp(),
    });

    await db().doc(`users/${uid}`).update({
      ownedRestaurantId: restaurantId,
      pendingClaimRestaurantId: FieldValue.delete(),
      pendingClaimCode: FieldValue.delete(),
      businessVerificationStatus: "verified",
      updatedAt: FieldValue.serverTimestamp(),
    });

    const others = await restRef.collection("claimRequests").get();
    const batch = db().batch();
    for (const doc of others.docs) {
      if (doc.id === uid) continue;
      if (doc.data().status === "pending") {
        batch.update(doc.ref, {
          status: "rejected",
          rejectReason: "another_owner_verified",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }
    if (others.docs.length > 1) {
      await batch.commit();
    }
  },
);
