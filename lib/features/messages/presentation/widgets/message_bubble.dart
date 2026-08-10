import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/message.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showReadReceipt = false,
    this.isRead = false,
  });

  final Message message;
  final bool isMine;

  /// Only shown under the sender's latest message.
  final bool showReadReceipt;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(AppRadius.lg),
      topRight: const Radius.circular(AppRadius.lg),
      bottomLeft: Radius.circular(isMine ? AppRadius.lg : AppRadius.xs),
      bottomRight: Radius.circular(isMine ? AppRadius.xs : AppRadius.lg),
    );

    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            left: isMine ? 64 : AppSpacing.md,
            right: isMine ? AppSpacing.md : 64,
            top: AppSpacing.xxs,
            bottom: AppSpacing.xxs,
          ),
          child: message.type == MessageType.image
              ? ClipRRect(
                  borderRadius: radius,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 240,
                      maxHeight: 320,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: message.imageUrl ?? '',
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 240,
                        height: 240,
                        color: AppColors.primaryLight.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: isMine ? AppColors.primary : theme.colorScheme.surface,
                    borderRadius: radius,
                    border: isMine
                        ? null
                        : Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Text(
                    message.text ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isMine ? Colors.white : null,
                    ),
                  ),
                ),
        ),
        if (showReadReceipt)
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.md,
              bottom: AppSpacing.xxs,
            ),
            child: Text(
              isRead
                  ? 'Seen'
                  : 'Sent · ${Formatters.relativeTime(message.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
