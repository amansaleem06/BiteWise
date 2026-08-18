import 'dart:math' as math;

import '../../../core/constants/cuisines.dart';
import '../../feed/domain/entities/post.dart';

/// A traveler-style stamp for one cuisine.
class CuisineStamp {
  const CuisineStamp({
    required this.cuisine,
    required this.count,
  });

  final String cuisine;

  /// How many plates the user has posted with this cuisine tag.
  final int count;

  bool get earned => count > 0;
}

/// Foodie rank derived from how many cuisine stamps are earned.
enum TasteLevel {
  firstBite('First Bite', 0),
  nibbler('Nibbler', 1),
  taster('Taster', 3),
  gourmand('Gourmand', 6),
  connoisseur('Connoisseur', 10),
  tasteLegend('Taste Legend', 14);

  const TasteLevel(this.title, this.requiredStamps);

  final String title;
  final int requiredStamps;

  static TasteLevel forStamps(int stamps) {
    var level = TasteLevel.firstBite;
    for (final l in TasteLevel.values) {
      if (stamps >= l.requiredStamps) level = l;
    }
    return level;
  }

  TasteLevel? get next {
    final i = TasteLevel.values.indexOf(this);
    return i + 1 < TasteLevel.values.length ? TasteLevel.values[i + 1] : null;
  }
}

/// Everything the Taste Passport and Taste Match need, computed
/// client-side from a user's posts — no new backend data required.
class TasteStats {
  const TasteStats({
    required this.uid,
    required this.postCount,
    required this.stamps,
    required this.restaurantNamesById,
    this.averageRating,
  });

  final String uid;
  final int postCount;

  /// One entry per canonical cuisine, in [Cuisines.all] order.
  final List<CuisineStamp> stamps;

  /// Distinct restaurants this user has posted from, id → display name.
  final Map<String, String> restaurantNamesById;

  Set<String> get restaurantIds => restaurantNamesById.keys.toSet();

  /// Average of the ratings this user has given, null if none.
  final double? averageRating;

  int get earnedStampCount => stamps.where((s) => s.earned).length;

  TasteLevel get level => TasteLevel.forStamps(earnedStampCount);

  /// 0..1 progress from the current level to the next one.
  double get progressToNext {
    final next = level.next;
    if (next == null) return 1;
    final span = next.requiredStamps - level.requiredStamps;
    if (span <= 0) return 1;
    return ((earnedStampCount - level.requiredStamps) / span).clamp(0.0, 1.0);
  }

  List<CuisineStamp> get earnedStamps =>
      stamps.where((s) => s.earned).toList()
        ..sort((a, b) => b.count.compareTo(a.count));

  static TasteStats fromPosts(String uid, List<Post> posts) {
    final counts = <String, int>{for (final c in Cuisines.all) c: 0};
    final restaurants = <String, String>{};
    var ratingSum = 0.0;
    var ratingCount = 0;

    for (final post in posts) {
      for (final tag in post.tags) {
        final lower = tag.trim().toLowerCase();
        for (final cuisine in Cuisines.all) {
          if (lower == cuisine.toLowerCase()) {
            counts[cuisine] = counts[cuisine]! + 1;
          }
        }
      }
      if (post.restaurantId.isNotEmpty) {
        restaurants.putIfAbsent(
          post.restaurantId,
          post.restaurantName.trim,
        );
      }
      if (post.rating != null) {
        ratingSum += post.rating!;
        ratingCount++;
      }
    }

    return TasteStats(
      uid: uid,
      postCount: posts.length,
      stamps: [
        for (final c in Cuisines.all)
          CuisineStamp(cuisine: c, count: counts[c]!),
      ],
      restaurantNamesById: restaurants,
      averageRating: ratingCount > 0 ? ratingSum / ratingCount : null,
    );
  }
}

/// Similarity between two taste profiles.
class TasteMatch {
  const TasteMatch({
    required this.percent,
    required this.sharedCuisines,
    required this.sharedRestaurants,
    required this.mine,
    required this.theirs,
  });

  /// 0–100. Null-safe consumers should check [hasEnoughData] first.
  final int percent;
  final List<String> sharedCuisines;
  final List<String> sharedRestaurants;
  final TasteStats mine;
  final TasteStats theirs;

  bool get hasEnoughData => mine.postCount > 0 && theirs.postCount > 0;

  static TasteMatch compute(TasteStats mine, TasteStats theirs) {
    // Cosine similarity over cuisine-count vectors.
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    final shared = <String>[];
    for (var i = 0; i < mine.stamps.length; i++) {
      final a = mine.stamps[i].count.toDouble();
      final b = theirs.stamps[i].count.toDouble();
      dot += a * b;
      normA += a * a;
      normB += b * b;
      if (a > 0 && b > 0) shared.add(mine.stamps[i].cuisine);
    }
    final cosine = (normA == 0 || normB == 0)
        ? 0.0
        : dot / (math.sqrt(normA) * math.sqrt(normB));

    // Jaccard overlap of restaurants visited.
    final sharedIds = mine.restaurantIds.intersection(theirs.restaurantIds);
    final unionSize =
        mine.restaurantIds.union(theirs.restaurantIds).length;
    final jaccard = unionSize == 0 ? 0.0 : sharedIds.length / unionSize;

    // Rating style: how close their average scores are (4-star spread).
    var ratingAffinity = 0.5;
    if (mine.averageRating != null && theirs.averageRating != null) {
      ratingAffinity =
          1 - ((mine.averageRating! - theirs.averageRating!).abs() / 4)
              .clamp(0.0, 1.0);
    }

    final score = cosine * 0.6 + jaccard * 0.25 + ratingAffinity * 0.15;

    // Names for the shared spots (both users have posted from them).
    final sharedNames = sharedIds
        .map((id) => mine.restaurantNamesById[id] ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    return TasteMatch(
      percent: (score * 100).round().clamp(0, 100),
      sharedCuisines: shared,
      sharedRestaurants: sharedNames,
      mine: mine,
      theirs: theirs,
    );
  }
}
