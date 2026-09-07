import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/author_nav.dart';
import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/feed_providers.dart';
import 'feed_shimmer.dart';
import 'post_card.dart';
import 'post_actions_sheet.dart';
import 'share_post_sheet.dart';

class FeedList extends ConsumerStatefulWidget {
  const FeedList({super.key, required this.tab, this.cuisineFilter});

  final FeedTab tab;
  final String? cuisineFilter;

  @override
  ConsumerState<FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<FeedList> {
  final _scroll = ScrollController();
  var _showBackToTop = false;

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
    final offset = _scroll.position.pixels;
    final show = offset > 700;
    if (show != _showBackToTop) {
      setState(() => _showBackToTop = show);
    }
    if (offset >= _scroll.position.maxScrollExtent - 400) {
      ref.read(feedControllerProvider(widget.tab).notifier).loadMore();
    }
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: AppDurations.normal,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _share(String postId, String restaurant, String caption) {
    return SharePostSheet.show(
      context,
      postId: postId,
      restaurantName: restaurant,
      caption: caption,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(plateScrollToTopTickProvider, (_, __) => _scrollToTop());

    final feedAsync = ref.watch(feedControllerProvider(widget.tab));
    final controller = ref.read(feedControllerProvider(widget.tab).notifier);

    return feedAsync.when(
      loading: () => const FeedShimmer(),
      error: (error, _) => AppEmptyState(
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
                  child: AppEmptyState(
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

        return Stack(
          children: [
            RefreshIndicator(
              onRefresh: controller.refresh,
              color: AppColors.primary,
              child: ListView.builder(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 160, top: 4),
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
                    onBookmark: () {
                      final wasSaved = post.isBookmarkedByMe;
                      controller.toggleBookmark(post.id);
                      if (wasSaved && context.mounted) {
                        AppSnackbar.undo(
                          context,
                          'Removed from saved',
                          onUndo: () => controller.toggleBookmark(post.id),
                        );
                      }
                    },
                    onRepost: () => controller.toggleRepost(post.id),
                    onComment: () => context.push(Routes.postPath(post.id)),
                    onShare: () => _share(
                      post.id,
                      post.restaurantName,
                      post.caption,
                    ),
                    onAuthorTap: () => openPostAuthor(context, post),
                    onRestaurantTap: () => context.push(
                      Routes.restaurantPath(post.restaurantId),
                    ),
                    onOpenActions: () => PostActionsSheet.show(
                      context,
                      post: post,
                      feedTab: widget.tab,
                    ),
                  );
                },
              ),
            ),
            if (_showBackToTop)
              Positioned(
                right: AppSpacing.md,
                bottom: 168,
                child: FloatingActionButton.small(
                  heroTag: 'feed-back-top-${widget.tab.name}',
                  tooltip: 'Back to top',
                  onPressed: _scrollToTop,
                  child: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
              ),
          ],
        );
      },
    );
  }
}

