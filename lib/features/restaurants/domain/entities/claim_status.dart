/// Business-account verification lifecycle.
enum BusinessVerificationStatus {
  pending,
  verified,
  rejected;

  static BusinessVerificationStatus? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    return BusinessVerificationStatus.values
        .where((s) => s.name == key)
        .firstOrNull;
  }
}

/// Restaurant claim lifecycle. Independent of ratings, which always live
/// on the restaurant document and carry over when a listing is claimed.
enum ClaimStatus {
  unclaimed,
  pending,
  claimed;

  static ClaimStatus fromKey(String? key, {bool claimed = false}) {
    if (key == 'pending') return ClaimStatus.pending;
    if (key == 'claimed' || claimed) return ClaimStatus.claimed;
    return ClaimStatus.unclaimed;
  }
}
