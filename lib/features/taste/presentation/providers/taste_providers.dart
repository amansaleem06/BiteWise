import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/taste_stats.dart';

/// Taste profile for any user, built from up to ~120 of their latest posts.
final tasteStatsProvider =
    FutureProvider.autoDispose.family<TasteStats, String>((ref, uid) async {
  final repo = ref.read(userRepositoryProvider);
  final posts = <Post>[];
  Object? cursor;
  for (var page = 0; page < 4; page++) {
    final result = await repo.fetchUserPosts(uid, cursor: cursor, limit: 30);
    posts.addAll(result.posts);
    if (!result.hasMore || result.cursor == null) break;
    cursor = result.cursor;
  }
  return TasteStats.fromPosts(uid, posts);
});

/// Compatibility between the signed-in viewer and [otherUid].
final tasteMatchProvider =
    FutureProvider.autoDispose.family<TasteMatch?, String>(
  (ref, otherUid) async {
    final me = ref.watch(currentUserProvider)?.uid;
    if (me == null || me == otherUid) return null;
    final results = await Future.wait([
      ref.watch(tasteStatsProvider(me).future),
      ref.watch(tasteStatsProvider(otherUid).future),
    ]);
    return TasteMatch.compute(results[0], results[1]);
  },
);
