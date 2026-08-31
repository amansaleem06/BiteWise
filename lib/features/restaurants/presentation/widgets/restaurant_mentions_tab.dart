import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../feed/domain/entities/post.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../domain/entities/restaurant.dart';
import '../providers/restaurant_providers.dart';

/// Diner posts that tagged this restaurant — separate from official page posts.
class RestaurantMentionsTab extends ConsumerWidget {
  const RestaurantMentionsTab({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(currentUserProvider);
    final isOwner = me != null && restaurant.ownerId == me.uid;
    final postsAsync = ref.watch(restaurantPostsProvider(restaurant.id));
    final controller =
        ref.read(restaurantPostsProvider(restaurant.id).notifier);

    return postsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
      error: (_, __) => Center(
        child: TextButton(
          onPressed: () =>
              ref.invalidate(restaurantPostsProvider(restaurant.id)),
          child: const Text('Retry'),
        ),
      ),
      data: (feed) {
        final mentions = feed.posts
            .where(
              (p) => p.visibleOnMentions(
                approvalRequired:
                    restaurant.guestFeedMode == GuestFeedMode.approved,
                viewerIsOwner: isOwner,
              ),
            )
            .toList();

        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
              controller.loadMore();
            }
            return false;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
            children: [
              if (isOwner) ...[
                Text(
                  'Diner tags',
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Posts where someone tagged ${restaurant.name} stay here. They never appear as your official page posts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<GuestFeedMode>(
                  segments: const [
                    ButtonSegment(
                      value: GuestFeedMode.all,
                      label: Text('Show all'),
                      icon: Icon(Icons.public_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: GuestFeedMode.approved,
                      label: Text('Only approved'),
                      icon: Icon(Icons.verified_outlined, size: 18),
                    ),
                  ],
                  selected: {restaurant.guestFeedMode},
                  onSelectionChanged: (value) async {
                    try {
                      await ref
                          .read(
                            restaurantControllerProvider(restaurant.id)
                                .notifier,
                          )
                          .setGuestFeedMode(value.first);
                    } catch (e) {
                      if (context.mounted) {
                        AppSnackbar.error(context, userMessageFrom(e));
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'From diners',
                  style: GoogleFonts.fraunces(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Photos guests tagged at ${restaurant.name}. Official posts from the restaurant are in Posts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (mentions.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32),
                  child: Text(
                    isOwner
                        ? restaurant.guestFeedMode == GuestFeedMode.approved
                            ? 'No diner tags yet — or none approved. Switch to “Show all” to review incoming posts.'
                            : 'No diner tags yet. When someone tags this restaurant, it will show up here.'
                        : 'No diner photos to show yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final post in mentions)
                  _MentionTile(
                    post: post,
                    isOwner: isOwner,
                    restaurantId: restaurant.id,
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _MentionTile extends ConsumerWidget {
  const _MentionTile({
    required this.post,
    required this.isOwner,
    required this.restaurantId,
  });

  final Post post;
  final bool isOwner;
  final String restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final media = post.media.isNotEmpty ? post.media.first : null;
    final status = post.mentionHidden
        ? 'Hidden'
        : post.mentionApproved
            ? 'Showing'
            : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => context.push(Routes.postPath(post.id)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: media == null
                        ? const ColoredBox(color: AppColors.primaryLight)
                        : CachedNetworkImage(
                            imageUrl: media.type == MediaType.video
                                ? (media.thumbnailUrl ?? media.url)
                                : media.url,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.caption.isNotEmpty
                            ? post.caption
                            : (post.dishName ?? 'Tagged this restaurant'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 6),
                        Text(
                          status,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: post.mentionHidden
                                ? theme.colorScheme.error
                                : AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      try {
                        if (value == 'show') {
                          await ref.read(feedRepositoryProvider).moderateMention(
                                post.id,
                                approved: true,
                                hidden: false,
                              );
                        } else {
                          await ref.read(feedRepositoryProvider).moderateMention(
                                post.id,
                                approved: false,
                                hidden: true,
                              );
                        }
                        ref.invalidate(restaurantPostsProvider(restaurantId));
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.error(context, userMessageFrom(e));
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'show',
                        child: Text('Show on page'),
                      ),
                      const PopupMenuItem(
                        value: 'hide',
                        child: Text('Hide from page'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
