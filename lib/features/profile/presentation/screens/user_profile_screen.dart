import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../messages/presentation/providers/chat_providers.dart';
import '../../../safety/domain/repositories/safety_repository.dart';
import '../../../safety/presentation/providers/safety_providers.dart';
import '../../../safety/presentation/widgets/safety_actions.dart';
import '../../../taste/presentation/widgets/taste_match_card.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_widgets.dart';

/// Another user's profile (or your own, viewed via a link).
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  Future<void> _toggleFollow(BuildContext context, WidgetRef ref) async {
    final error =
        await ref.read(userProfileProvider(uid).notifier).toggleFollow();
    if (error != null && context.mounted) {
      AppSnackbar.error(context, error);
    }
  }

  Future<void> _openMessage(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(userProfileProvider(uid)).valueOrNull;
    if (profile == null) return;
    try {
      final chatId = await ref.read(chatRepositoryProvider).openChatWith(
            peerUid: profile.user.uid,
            peerName: profile.user.displayName,
            peerPhotoUrl: profile.user.photoUrl,
          );
      if (context.mounted) context.push(Routes.chatPath(chatId));
    } catch (e) {
      if (context.mounted) AppSnackbar.error(context, userMessageFrom(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));
    final isSelf = ref.watch(currentUserProvider)?.uid == uid;
    final blocked = ref.watch(blockedUserIdsProvider).valueOrNull ?? {};
    final isBlocked = blocked.contains(uid);

    return Scaffold(
      appBar: AppBar(
        title: Text(profileAsync.valueOrNull?.user.displayName ?? ''),
        actions: [
          if (!isSelf)
            PopupMenuButton<String>(
              onSelected: (value) {
                final name =
                    profileAsync.valueOrNull?.user.displayName ?? 'this user';
                if (value == 'report') {
                  SafetyActions.report(
                    context,
                    ref,
                    type: ReportTargetType.user,
                    targetId: uid,
                    targetUserId: uid,
                  );
                } else if (value == 'block') {
                  SafetyActions.blockUser(
                    context,
                    ref,
                    uid: uid,
                    name: name,
                  );
                } else if (value == 'unblock') {
                  SafetyActions.unblockUser(context, ref, uid: uid);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'report',
                  child: Text('Report user'),
                ),
                if (isBlocked)
                  const PopupMenuItem(
                    value: 'unblock',
                    child: Text('Unblock'),
                  )
                else
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Block user'),
                  ),
              ],
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (error, stack) => AsyncErrorView(
          error: error,
          stackTrace: stack,
          title: 'Couldn\'t load this profile',
          onRetry: () => ref.invalidate(userProfileProvider(uid)),
        ),
        data: (profile) => Column(
          children: [
            ProfileHeader(
              user: profile.user,
              trailing: isSelf
                  ? null
                  : Row(
                      children: [
                        Expanded(
                          child: profile.isFollowedByMe
                              ? OutlinedButton(
                                  onPressed: () => _toggleFollow(context, ref),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                  child: const Text('Following'),
                                )
                              : FilledButton(
                                  onPressed: () => _toggleFollow(context, ref),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                  child: const Text('Follow'),
                                ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openMessage(context, ref),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(40),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                size: 18,),
                            label: const Text('Message'),
                          ),
                        ),
                      ],
                    ),
            ),
            if (!isSelf && isBlocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  'You blocked this user. Their posts are hidden from your feed.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (!isSelf)
              TasteMatchCard(uid: uid, name: profile.user.displayName),
            const Divider(height: 1),
            Expanded(child: UserPostsGrid(uid: uid)),
          ],
        ),
      ),
    );
  }
}
