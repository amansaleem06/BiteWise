import 'package:bitewise/features/explore/domain/services/trending_ranker.dart';
import 'package:bitewise/features/feed/domain/entities/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 22, 12);

  Post post(
    String id, {
    required Duration age,
    int likes = 0,
    int comments = 0,
    int shares = 0,
  }) =>
      Post(
        id: id,
        authorId: 'author-$id',
        authorName: 'Author',
        restaurantId: '',
        restaurantName: '',
        media: const [],
        likeCount: likes,
        commentCount: comments,
        shareCount: shares,
        createdAt: now.subtract(age),
      );

  List<String> rank(Iterable<Post> posts) => TrendingRanker.rank(
        posts,
        now: now,
      ).map((item) => item.post.id).toList();

  test('recent six-like post outranks a 21-day-old three-like post', () {
    final old = post('old', age: const Duration(days: 21), likes: 3);
    final recent = post('recent', age: const Duration(days: 1), likes: 6);

    expect(rank([old, recent]), ['recent', 'old']);
  });

  test('strong engagement can outweigh being the newest post', () {
    final newest = post('newest', age: const Duration(hours: 1), likes: 1);
    final engaged = post('engaged', age: const Duration(days: 2), likes: 20);

    expect(rank([newest, engaged]), ['engaged', 'newest']);
  });

  test('recency breaks similar engagement in the expected direction', () {
    final older = post('older', age: const Duration(days: 2), likes: 5);
    final newer = post('newer', age: const Duration(days: 1), likes: 5);

    expect(rank([older, newer]), ['newer', 'older']);
  });

  test('significant new engagement can revive an older post', () {
    final older = post('older', age: const Duration(days: 10), likes: 50);
    final recent = post('recent', age: const Duration(days: 1), likes: 5);

    expect(rank([recent, older]), ['older', 'recent']);
  });

  test('comments and shares carry more weight than likes', () {
    final likes = post('likes', age: const Duration(hours: 3), likes: 3);
    final discussion = post(
      'discussion',
      age: const Duration(hours: 3),
      comments: 1,
      shares: 1,
    );

    expect(rank([likes, discussion]), ['discussion', 'likes']);
  });

  test('duplicate post IDs are returned once', () {
    final item = post('same', age: const Duration(hours: 1), likes: 2);

    expect(rank([item, item]), ['same']);
  });
}
