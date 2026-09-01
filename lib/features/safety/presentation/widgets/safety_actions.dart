import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_legal.dart';
import '../../../../core/constants/contact_support.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../feed/presentation/providers/feed_providers.dart';
import '../../../messages/presentation/providers/chat_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/repositories/safety_repository.dart';
import '../providers/safety_providers.dart';

/// Shared report / block flows for App Store Guideline 1.2.
abstract final class SafetyActions {
  static const reasons = <String>[
    'Spam',
    'Harassment',
    'Hate or abuse',
    'Sexual or inappropriate content',
    'Impersonation',
    'Other',
  ];

  static Future<void> report(
    BuildContext context,
    WidgetRef ref, {
    required ReportTargetType type,
    required String targetId,
    required String targetUserId,
  }) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(
                'Report',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                'We’ll review this. For extra help email ${AppLegal.supportEmail}.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ),
            for (final item in reasons)
              ListTile(
                title: Text(item),
                onTap: () => Navigator.pop(ctx, item),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;

    try {
      await ref.read(safetyRepositoryProvider).report(
            type: type,
            targetId: targetId,
            targetUserId: targetUserId,
            reason: reason,
          );
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Report received'),
            content: const Text(
              'Thanks. We’ll review this. If you need to follow up, email ${AppLegal.supportEmail}.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ContactSupport.copyEmail(context);
                },
                child: const Text('Copy email'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ContactSupport.email(
                    context,
                    subject: 'TasteWise report',
                  );
                },
                child: const Text('Email support'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, userMessageFrom(e));
      }
    }
  }

  static Future<void> blockUser(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
    String name = 'this user',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this user?'),
        content: Text(
          'You won’t see $name’s posts or messages. You can unblock them later from their profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(safetyRepositoryProvider).blockUser(uid);
      ref.invalidate(feedControllerProvider(FeedTab.forYou));
      ref.invalidate(feedControllerProvider(FeedTab.following));
      ref.invalidate(chatsProvider);
      ref.invalidate(userPostsProvider(uid));
      if (context.mounted) {
        AppSnackbar.success(context, 'User blocked');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, userMessageFrom(e));
      }
    }
  }

  static Future<void> unblockUser(
    BuildContext context,
    WidgetRef ref, {
    required String uid,
  }) async {
    try {
      await ref.read(safetyRepositoryProvider).unblockUser(uid);
      ref.invalidate(feedControllerProvider(FeedTab.forYou));
      ref.invalidate(feedControllerProvider(FeedTab.following));
      ref.invalidate(chatsProvider);
      if (context.mounted) {
        AppSnackbar.success(context, 'User unblocked');
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.error(context, userMessageFrom(e));
      }
    }
  }
}
