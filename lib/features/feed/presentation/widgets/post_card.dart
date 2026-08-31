import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/post.dart';
import 'media_carousel.dart';

/// Editorial Taste Stage plate — media hero + score badge + action tray.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onBookmark,
    this.onComment,
    this.onShare,
    this.onRepost,
    this.onRestaurantTap,
    this.onAuthorTap,
    this.onOpenActions,
  });

  final Post post;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onRepost;
  final VoidCallback? onRestaurantTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onOpenActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surface;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.35)
                : AppColors.charcoal.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: onAuthorTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    backgroundImage: post.authorPhotoUrl != null
                        ? NetworkImage(post.authorPhotoUrl!)
                        : null,
                    child: post.authorPhotoUrl == null
                        ? Text(
                            post.publicAuthorName.isNotEmpty
                                ? post.publicAuthorName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onAuthorTap,
                        child: Text(
                          post.publicAuthorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.sourceSans3(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
          if (post.hasRestaurant && !post.postedAsRestaurant)
                        GestureDetector(
                          onTap: onRestaurantTap,
                          child: Text(
                            post.restaurantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.sourceSans3(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (post.postedAsRestaurant)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        post.pageKind == PagePostKind.plate
                            ? 'Page'
                            : post.pageKind.label,
                        style: GoogleFonts.sourceSans3(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                if (post.postedAsRestaurant)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.verified_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                IconButton(
                  onPressed: onOpenActions,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              MediaCarousel(
                media: post.media,
                onDoubleTap: post.isLikedByMe ? null : onLike,
              ),
              if (post.postedAsRestaurant &&
                  post.pageKind == PagePostKind.promo &&
                  post.hasRestaurant)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Material(
                    color: AppColors.primary.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      onTap: onRestaurantTap,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              color: AppColors.cream,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Get yours here',
                              style: GoogleFonts.sourceSans3(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (post.rating != null)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.ratingStar,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.rating!.toStringAsFixed(1),
                          style: GoogleFonts.sourceSans3(
                            color: AppColors.cream,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                _TrayAction(
                  icon: post.isLikedByMe
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: post.isLikedByMe
                      ? AppColors.primary
                      : theme.colorScheme.onSurface,
                  label: post.likeCount > 0
                      ? Formatters.compactCount(post.likeCount)
                      : null,
                  onTap: onLike,
                ),
                _TrayAction(
                  icon: Icons.mode_comment_outlined,
                  color: theme.colorScheme.onSurface,
                  label: post.commentCount > 0
                      ? Formatters.compactCount(post.commentCount)
                      : null,
                  onTap: onComment,
                ),
                _TrayAction(
                  icon: Icons.ios_share_rounded,
                  color: theme.colorScheme.onSurface,
                  label: post.shareCount > 0
                      ? Formatters.compactCount(post.shareCount)
                      : null,
                  onTap: onShare,
                ),
                _TrayAction(
                  icon: post.isRepostedByMe
                      ? Icons.repeat_on_rounded
                      : Icons.repeat_rounded,
                  color: post.isRepostedByMe
                      ? AppColors.accent
                      : theme.colorScheme.onSurface,
                  onTap: onRepost,
                ),
                const Spacer(),
                _TrayAction(
                  icon: post.isBookmarkedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: post.isBookmarkedByMe
                      ? AppColors.accentDark
                      : theme.colorScheme.onSurface,
                  onTap: onBookmark,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.dishName != null && post.dishName!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      post.dishName!,
                      style: GoogleFonts.fraunces(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                if (post.caption.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${post.publicAuthorName} ',
                          style: GoogleFonts.sourceSans3(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        TextSpan(
                          text: post.caption,
                          style: GoogleFonts.sourceSans3(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (post.hasCommentPreview) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onComment,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${post.previewCommentAuthor ?? 'Comment'} ',
                              style: GoogleFonts.sourceSans3(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            TextSpan(
                              text: post.previewCommentText!,
                              style: GoogleFonts.sourceSans3(
                                fontSize: 13,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.85),
                              ),
                            ),
                            if (post.commentCount > 1)
                              TextSpan(
                                text: '  · View all ${post.commentCount}',
                                style: GoogleFonts.sourceSans3(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ] else if (post.commentCount > 0) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onComment,
                    child: Text(
                      'View ${post.commentCount} comment${post.commentCount == 1 ? '' : 's'}',
                      style: GoogleFonts.sourceSans3(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < post.tags.length && i < 4; i++)
                        _TagPill(label: post.tags[i], index: i),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  Formatters.relativeTime(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    const styles = [
      (AppColors.primaryLight, AppColors.primary),
      (AppColors.cream, AppColors.primary),
    ];
    final style = styles[index % styles.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: style.$1,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: GoogleFonts.sourceSans3(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: style.$2,
        ),
      ),
    );
  }
}

class _TrayAction extends StatelessWidget {
  const _TrayAction({
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
