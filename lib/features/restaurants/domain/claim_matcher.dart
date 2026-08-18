import 'entities/claim_status.dart';

/// Cross-check business signup details against a Maps restaurant listing.
abstract final class ClaimMatcher {
  /// Strong match → auto-claim. Weak/mismatch → pending manual review.
  static bool isStrongMatch({
    required String businessName,
    String? businessAddress,
    required String restaurantName,
    String? restaurantAddress,
  }) {
    final bn = _norm(businessName);
    final rn = _norm(restaurantName);
    if (bn.isEmpty || rn.isEmpty) return false;

    final nameOk = bn == rn ||
        bn.contains(rn) ||
        rn.contains(bn) ||
        _tokenOverlap(bn, rn) >= 0.6;
    if (!nameOk) return false;

    final ba = _norm(businessAddress ?? '');
    final ra = _norm(restaurantAddress ?? '');
    if (ba.isEmpty || ra.isEmpty) return true;
    return ba.contains(ra) ||
        ra.contains(ba) ||
        _tokenOverlap(ba, ra) >= 0.35;
  }

  static String _norm(String raw) => raw
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static double _tokenOverlap(String a, String b) {
    const skip = {'the', 'and', 'of', 'at', 'in', 'a', 'an', 'restaurant'};
    final ta =
        a.split(' ').where((t) => t.length > 1 && !skip.contains(t)).toSet();
    final tb =
        b.split(' ').where((t) => t.length > 1 && !skip.contains(t)).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0;
    return ta.intersection(tb).length / ta.union(tb).length;
  }
}

class ClaimResult {
  const ClaimResult({
    required this.restaurantId,
    required this.status,
  });

  final String restaurantId;
  final ClaimStatus status;

  bool get isApproved => status == ClaimStatus.claimed;
}
