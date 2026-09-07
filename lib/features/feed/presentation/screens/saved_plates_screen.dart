import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/author_nav.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../feed/presentation/widgets/feed_shimmer.dart';
import '../../../feed/presentation/widgets/post_card.dart';

final savedPlatesProvider =
    FutureProvider.autoDispose<List<Post>>((ref) async {
  final page = await ref.watch(feedRepositoryProvider).fetchBookmarks(limit: 40);
  return page.posts;
});

/// Saved shelf under Table / Settings.
class SavedPlatesScreen extends ConsumerWidget {
  const SavedPlatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(savedPlatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved plates',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w800),
        ),
      ),
      body: async.when(
        loading: () => const FeedShimmer(itemCount: 2),
        error: (e, st) => AsyncErrorView(
          error: e,
          stackTrace: st,
          title: 'Couldn\'t load saved plates',
          onRetry: () => ref.invalidate(savedPlatesProvider),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const AppEmptyState(
              icon: Icons.bookmark_outline_rounded,
              title: 'No saved plates yet',
              subtitle: 'Tap the bookmark on a post to keep it here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxl, top: 8),
            itemCount: posts.length,
            itemBuilder: (context, i) {
              final post = posts[i];
              return PostCard(
                post: post,
                onLike: () {},
                onBookmark: () async {
                  await ref
                      .read(feedRepositoryProvider)
                      .setBookmarked(post.id, bookmarked: false);
                  ref.invalidate(savedPlatesProvider);
                  if (!context.mounted) return;
                  AppSnackbar.undo(
                    context,
                    'Removed from saved',
                    onUndo: () async {
                      await ref
                          .read(feedRepositoryProvider)
                          .setBookmarked(post.id, bookmarked: true);
                      ref.invalidate(savedPlatesProvider);
                    },
                  );
                },
                onComment: () => context.push(Routes.postPath(post.id)),
                onAuthorTap: () => openPostAuthor(context, post),
                onRestaurantTap: () =>
                    context.push(Routes.restaurantPath(post.restaurantId)),
              );
            },
          );
        },
      ),
    );
  }
}
