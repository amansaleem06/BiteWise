import 'dart:math' as math;

import '../../../feed/domain/entities/post.dart';

class TrendingScore {
  const TrendingScore({
    required this.post,
    required this.engagement,
    required this.ageHours,
    required this.decay,
    required this.value,
  });

  final Post post;
  final double engagement;
  final double ageHours;
  final double decay;
  final double value;
}

/// Deterministic early-stage ranking: meaningful at single-digit engagement
/// counts while still allowing a strongly engaged older post to resurface.
abstract final class TrendingRanker {
  static const double halfLifeHours = 72;

  static TrendingScore score(Post post, {required DateTime now}) {
    final createdAt = post.createdAt ?? now;
    final ageHours = math.max(
      0,
      now.difference(createdAt).inMinutes / 60,
    ).toDouble();
    final engagement = 1 +
        post.likeCount.toDouble() +
        post.commentCount * 2.0 +
        post.shareCount * 2.0;
    final decay = math.pow(0.5, ageHours / halfLifeHours).toDouble();
    return TrendingScore(
      post: post,
      engagement: engagement,
      ageHours: ageHours,
      decay: decay,
      value: engagement * decay,
    );
  }

  static List<TrendingScore> rank(
    Iterable<Post> posts, {
    required DateTime now,
  }) {
    final unique = <String, Post>{};
    for (final post in posts) {
      unique.putIfAbsent(post.id, () => post);
    }
    final scored = [
      for (final post in unique.values) score(post, now: now),
    ]..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        if (byScore != 0) return byScore;
        final byEngagement = b.engagement.compareTo(a.engagement);
        if (byEngagement != 0) return byEngagement;
        final aCreated = a.post.createdAt ?? now;
        final bCreated = b.post.createdAt ?? now;
        final byCreated = bCreated.compareTo(aCreated);
        if (byCreated != 0) return byCreated;
        return a.post.id.compareTo(b.post.id);
      });
    return scored;
  }

  static String explain(TrendingScore score) {
    final post = score.post;
    return 'post=${post.id} created=${post.createdAt?.toUtc().toIso8601String() ?? 'pending'} '
        'likes=${post.likeCount} comments=${post.commentCount} '
        'shares=${post.shareCount} ageHours=${score.ageHours.toStringAsFixed(1)} '
        'engagement=${score.engagement.toStringAsFixed(1)} '
        'decay=${score.decay.toStringAsFixed(4)} '
        'score=${score.value.toStringAsFixed(4)}';
  }
}
