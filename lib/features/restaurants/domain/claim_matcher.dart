import 'dart:math';

import 'entities/claim_status.dart';

/// Cross-check business signup details against a Maps restaurant listing.
abstract final class ClaimMatcher {
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Unique code only the submitter and TasteWise support share.
  static String generateCode() {
    final random = Random.secure();
    final body = List.generate(
      6,
      (_) => _codeChars[random.nextInt(_codeChars.length)],
    ).join();
    return 'TW-$body';
  }

  static String digitsOnly(String? raw) =>
      (raw ?? '').replaceAll(RegExp(r'\D'), '');

  /// Compare national numbers by the last 7–8 digits.
  static bool phonesMatch(String? a, String? b) {
    final da = digitsOnly(a);
    final db = digitsOnly(b);
    if (da.isEmpty || db.isEmpty) return false;
    final n = (da.length < 8 || db.length < 8) ? 7 : 8;
    if (da.length < n || db.length < n) return da == db;
    return da.substring(da.length - n) == db.substring(db.length - n);
  }

  /// Name + address must line up with the Maps listing.
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
    this.claimCode,
  });

  final String restaurantId;
  final ClaimStatus status;
  final String? claimCode;

  bool get isApproved => status == ClaimStatus.claimed;
}
