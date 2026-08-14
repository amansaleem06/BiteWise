import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../providers/feed_providers.dart';
import 'feed_shimmer.dart';
import 'post_card.dart';

class FeedList extends ConsumerStatefulWidget {
  const FeedList({super.key, required this.tab, this.cuisineFilter});

  final FeedTab tab;
  final String? cuisineFilter;

  @override
  ConsumerState<FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<FeedList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(feedControllerProvider(widget.tab).notifier).loadMore();
    }
  }

  Future<void> _share(String postId, String restaurant, String caption) async {
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Taste this on TasteWise: $restaurant\n$caption\nhttps://tastewise.app/post/$postId',
      ),
    );
    await ref.read(feedControllerProvider(widget.tab).notifier).sharePost(postId);
  }

  void _openTray({
    required String postId,
    required bool bookmarked,
    required bool reposted,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border,
              ),
              title: Text(bookmarked ? 'Remove save' : 'Save plate'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(feedControllerProvider(widget.tab).notifier)
                    .toggleBookmark(postId);
              },
            ),
            ListTile(
              leading: Icon(
                reposted ? Icons.repeat_on_rounded : Icons.repeat_rounded,
              ),
              title: Text(reposted ? 'Undo repost' : 'Repost to Plate'),
              onTap: () {
                Navigator.pop(ctx);
                ref
                    .read(feedControllerProvider(widget.tab).notifier)
                    .toggleRepost(postId);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(plateScrollToTopTickProvider, (_, __) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
        );
      }
    });

    final feedAsync = ref.watch(feedControllerProvider(widget.tab));
    final controller = ref.read(feedControllerProvider(widget.tab).notifier);

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
        final posts = widget.cuisineFilter == null
            ? feed.posts
            : feed.posts
                .where(
                  (p) => p.tags.any(
                    (t) =>
                        t.toLowerCase() ==
                            widget.cuisineFilter!.toLowerCase() ||
                        t.toLowerCase().contains(
                              widget.cuisineFilter!.toLowerCase(),
                            ),
                  ),
                )
                .toList();

        if (posts.isEmpty) {
          return RefreshIndicator(
            onRefresh: controller.refresh,
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.55,
                  child: _MessageView(
                    icon: widget.tab == FeedTab.following
                        ? Icons.group_outlined
                        : Icons.restaurant_outlined,
                    title: widget.cuisineFilter != null
                        ? 'No ${widget.cuisineFilter} posts'
                        : widget.tab == FeedTab.following
                            ? 'Nothing here yet'
                            : 'No plates yet',
                    subtitle: widget.cuisineFilter != null
                        ? 'Try another cuisine, or tag a post when you publish.'
                        : widget.tab == FeedTab.following
                            ? 'Follow food lovers to fill your Following course.'
                            : 'Be the first to share a delicious bite.',
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refresh,
          color: AppColors.primary,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 120, top: 4),
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
                onRepost: () => controller.toggleRepost(post.id),
                onComment: () => context.push(Routes.postPath(post.id)),
                onShare: () => _share(
                  post.id,
                  post.restaurantName,
                  post.caption,
                ),
                onAuthorTap: () =>
                    context.push(Routes.userPath(post.authorId)),
                onRestaurantTap: () => context.push(
                  Routes.restaurantPath(post.restaurantId),
                ),
                onOpenActions: () => _openTray(
                  postId: post.id,
                  bookmarked: post.isBookmarkedByMe,
                  reposted: post.isRepostedByMe,
                ),
              );
            },
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
