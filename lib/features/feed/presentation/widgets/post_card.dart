import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/post.dart';
import 'media_carousel.dart';

/// The flagship feed component: header (author + restaurant), media,
/// actions, rating/price context, caption, and comment teaser.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onBookmark,
    this.onComment,
    this.onShare,
    this.onRestaurantTap,
    this.onAuthorTap,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onRestaurantTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.charcoal.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            post: post,
            onRestaurantTap: onRestaurantTap,
            onAuthorTap: onAuthorTap,
          ),
          MediaCarousel(
            media: post.media,
            onDoubleTap: post.isLikedByMe ? null : onLike,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xxs,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                _ActionButton(
                  icon: post.isLikedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.isLikedByMe
                      ? AppColors.primary
                      : AppColors.charcoal.withValues(alpha: 0.85),
                  label: post.likeCount > 0
                      ? Formatters.compactCount(post.likeCount)
                      : null,
                  onTap: onLike,
                ),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  color: AppColors.charcoal.withValues(alpha: 0.85),
                  label: post.commentCount > 0
                      ? Formatters.compactCount(post.commentCount)
                      : null,
                  onTap: onComment,
                ),
                _ActionButton(
                  icon: Icons.send_outlined,
                  color: AppColors.charcoal.withValues(alpha: 0.85),
                  onTap: onShare,
                ),
                const Spacer(),
                _ActionButton(
                  icon: post.isBookmarkedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: post.isBookmarkedByMe
                      ? AppColors.accent
                      : AppColors.charcoal.withValues(alpha: 0.85),
                  onTap: onBookmark,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xxs,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.rating != null || post.price != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                    child: _RatingPriceRow(post: post),
                  ),
                if (post.caption.isNotEmpty)
                  _Caption(
                    authorName: post.authorName,
                    caption: post.caption,
                  ),
                if (post.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      post.tags.map((t) => '#$t').join(' '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  Formatters.relativeTime(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post, this.onRestaurantTap, this.onAuthorTap});

  final Post post;
  final VoidCallback? onRestaurantTap;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAuthorTap,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryLight,
              backgroundImage: post.authorPhotoUrl != null
                  ? NetworkImage(post.authorPhotoUrl!)
                  : null,
              child: post.authorPhotoUrl == null
                  ? Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : '?',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: AppColors.primaryDark),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onAuthorTap,
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        ' · Member',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Restaurant is the place page — distinct from the member above.
                GestureDetector(
                  onTap: onRestaurantTap,
                  child: Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.feedAccentSoft,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            post.dishName != null
                                ? '${post.dishName} · ${post.restaurantName}'
                                : post.restaurantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}

class _RatingPriceRow extends StatelessWidget {
  const _RatingPriceRow({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (post.rating != null) ...[
          const Icon(Icons.star_rounded, size: 18, color: AppColors.ratingStar),
          const SizedBox(width: 2),
          Text(
            post.rating!.toStringAsFixed(1),
            style: theme.textTheme.titleSmall,
          ),
        ],
        if (post.rating != null && post.price != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text('·', style: theme.textTheme.bodySmall),
          ),
        if (post.price != null)
          Text(
            Formatters.price(post.price!, post.currencyCode),
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.authorName, required this.caption});

  final String authorName;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$authorName ',
            style: theme.textTheme.titleSmall,
          ),
          TextSpan(text: caption, style: theme.textTheme.bodyMedium),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: AppDurations.fast,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: 26,
                color: color ?? theme.colorScheme.onSurface,
              ),
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label!, style: theme.textTheme.titleSmall),
            ],
          ],
        ),
      ),
    );
  }
}
