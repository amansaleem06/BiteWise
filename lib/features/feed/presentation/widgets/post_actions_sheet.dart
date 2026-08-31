import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../restaurants/presentation/providers/restaurant_providers.dart';
import '../../domain/entities/post.dart';
import '../providers/feed_providers.dart';

/// Overflow menu for a plate: save, repost, delete, mention moderation.
class PostActionsSheet extends ConsumerWidget {
  const PostActionsSheet({
    super.key,
    required this.post,
    this.feedTab,
    this.onDeleted,
  });

  final Post post;
  final FeedTab? feedTab;
  final VoidCallback? onDeleted;

  static Future<void> show(
    BuildContext context, {
    required Post post,
    FeedTab? feedTab,
    VoidCallback? onDeleted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => PostActionsSheet(
        post: post,
        feedTab: feedTab,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final isAuthor = me != null && me.uid == post.authorId;
    final ownsTaggedRestaurant = me != null &&
        post.isMention &&
        post.restaurantId.isNotEmpty &&
        me.ownedRestaurantId == post.restaurantId;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              post.isBookmarkedByMe
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border,
            ),
            title: Text(post.isBookmarkedByMe ? 'Remove save' : 'Save plate'),
            onTap: () {
              Navigator.pop(context);
              if (feedTab != null) {
                ref
                    .read(feedControllerProvider(feedTab!).notifier)
                    .toggleBookmark(post.id);
              } else {
                ref
                    .read(feedRepositoryProvider)
                    .setBookmarked(post.id, bookmarked: !post.isBookmarkedByMe);
              }
            },
          ),
          ListTile(
            leading: Icon(
              post.isRepostedByMe
                  ? Icons.repeat_on_rounded
                  : Icons.repeat_rounded,
            ),
            title: Text(
              post.isRepostedByMe ? 'Undo repost' : 'Repost to Plate',
            ),
            onTap: () {
              Navigator.pop(context);
              if (feedTab != null) {
                ref
                    .read(feedControllerProvider(feedTab!).notifier)
                    .toggleRepost(post.id);
              } else {
                ref
                    .read(feedRepositoryProvider)
                    .setReposted(post.id, reposted: !post.isRepostedByMe);
              }
            },
          ),
          if (ownsTaggedRestaurant) ...[
            if (!post.mentionApproved || post.mentionHidden)
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Show on restaurant page'),
                subtitle: const Text('Diners will see this tag in Mentions'),
                onTap: () async {
                  Navigator.pop(context);
                  await _moderate(
                    context,
                    ref,
                    approved: true,
                    hidden: false,
                  );
                },
              ),
            if (!post.mentionHidden)
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Hide from restaurant page'),
                onTap: () async {
                  Navigator.pop(context);
                  await _moderate(
                    context,
                    ref,
                    approved: false,
                    hidden: true,
                  );
                },
              ),
          ],
          if (isAuthor)
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete post',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this post?'),
                    content: const Text(
                      'This removes the post from the feed and profiles. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true || !context.mounted) return;
                try {
                  if (feedTab != null) {
                    await ref
                        .read(feedControllerProvider(feedTab!).notifier)
                        .deletePost(post.id);
                  } else {
                    await ref.read(feedRepositoryProvider).deletePost(post.id);
                  }
                  ref.invalidate(feedControllerProvider(FeedTab.forYou));
                  ref.invalidate(feedControllerProvider(FeedTab.following));
                  ref.invalidate(userPostsProvider(post.authorId));
                  if (post.restaurantId.isNotEmpty) {
                    ref.invalidate(restaurantPostsProvider(post.restaurantId));
                    ref.invalidate(
                      restaurantControllerProvider(post.restaurantId),
                    );
                  }
                  if (context.mounted) {
                    AppSnackbar.success(context, 'Post deleted');
                  }
                  onDeleted?.call();
                } catch (e) {
                  if (context.mounted) {
                    AppSnackbar.error(context, userMessageFrom(e));
                  }
                }
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _moderate(
    BuildContext context,
    WidgetRef ref, {
    required bool approved,
    required bool hidden,
  }) async {
    try {
      await ref.read(feedRepositoryProvider).moderateMention(
            post.id,
            approved: approved,
            hidden: hidden,
          );
      if (post.restaurantId.isNotEmpty) {
        ref.invalidate(restaurantPostsProvider(post.restaurantId));
      }
      ref.invalidate(feedControllerProvider(FeedTab.forYou));
      if (context.mounted) {
        AppSnackbar.success(
          context,
          hidden ? 'Hidden from your page' : 'Showing on Mentions',
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, userMessageFrom(e));
      }
    }
  }
}
