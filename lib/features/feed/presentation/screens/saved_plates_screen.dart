import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/author_nav.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Saved plates',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.w800),
        ),
      ),
      body: async.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (e, _) => Center(child: Text('$e')),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Text(
                'No saved plates yet.\nBookmark a plate from the Stage.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
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
