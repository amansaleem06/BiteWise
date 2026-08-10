import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../providers/feed_providers.dart';
import 'feed_shimmer.dart';
import 'post_card.dart';

/// Infinite-scrolling feed for one tab: shimmer while loading, graceful
/// error + empty states, pull-to-refresh, and early prefetch of the next
/// page (400px before the end).
class FeedList extends ConsumerWidget {
  const FeedList({super.key, required this.tab, this.cuisineFilter});

  final FeedTab tab;
  final String? cuisineFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedControllerProvider(tab));
    final controller = ref.read(feedControllerProvider(tab).notifier);

    return feedAsync.when(
      loading: () => const FeedShimmer(),
      error: (error, _) => _MessageView(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn\'t load your feed',
        subtitle: userMessageFrom(error),
        actionLabel: AppStrings.retry,
        onAction: controller.refresh,
      ),
      data: (feed) {
        final posts = cuisineFilter == null
            ? feed.posts
            : feed.posts
                .where(
                  (p) => p.tags.any(
                    (t) =>
                        t.toLowerCase() == cuisineFilter!.toLowerCase() ||
                        t.toLowerCase().contains(
                              cuisineFilter!.toLowerCase(),
                            ),
                  ),
                )
                .toList();

        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            color: AppColors.primary,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _MessageView(
                    icon: tab == FeedTab.following
                        ? Icons.group_outlined
                        : Icons.restaurant_outlined,
                    title: cuisineFilter != null
                        ? 'No $cuisineFilter posts'
                        : tab == FeedTab.following
                            ? 'Nothing here yet'
                            : 'No posts yet',
                    subtitle: cuisineFilter != null
                        ? 'Try another cuisine, or tag a post when you publish.'
                        : tab == FeedTab.following
                            ? 'Follow food lovers and restaurants to build your feed.'
                            : 'Be the first to share a delicious bite.',
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: AppColors.primary,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.pixels >=
                  notification.metrics.maxScrollExtent - 400) {
                controller.loadMore();
              }
              return false;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: posts.length + (feed.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= posts.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }
                final post = posts[index];
                return PostCard(
                  post: post,
                  onLike: () => controller.toggleLike(post.id),
                  onBookmark: () => controller.toggleBookmark(post.id),
                  onComment: () => context.push(Routes.postPath(post.id)),
                  onAuthorTap: () =>
                      context.push(Routes.userPath(post.authorId)),
                  onRestaurantTap: () => context.push(
                    Routes.restaurantPath(post.restaurantId),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
