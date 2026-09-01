import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/comment.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    required this.isMine,
    required this.onReply,
    required this.onDelete,
    this.onReport,
  });

  final Comment comment;
  final bool isMine;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: comment.authorPhotoUrl != null
                ? NetworkImage(comment.authorPhotoUrl!)
                : null,
            child: comment.authorPhotoUrl == null
                ? Text(
                    comment.authorName.isNotEmpty
                        ? comment.authorName[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppColors.primaryDark),
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${comment.authorName} ',
                        style: theme.textTheme.titleSmall,
                      ),
                      if (comment.postedAsRestaurant)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              'Page ',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      if (comment.replyToName != null)
                        TextSpan(
                          text: '@${comment.replyToName} ',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      TextSpan(
                        text: comment.text,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      Formatters.relativeTime(comment.createdAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (!isMine && onReport != null) ...[
                      const SizedBox(width: AppSpacing.md),
                      GestureDetector(
                        onTap: onReport,
                        child: Text(
                          'Report',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    if (isMine) ...[
                      const SizedBox(width: AppSpacing.md),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          'Delete',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
