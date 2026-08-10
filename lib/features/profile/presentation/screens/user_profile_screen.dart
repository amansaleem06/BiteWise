import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_widgets.dart';

/// Another user's profile (or your own, viewed via a link).
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(uid));
    final isSelf = ref.watch(currentUserProvider)?.uid == uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(profileAsync.valueOrNull?.user.displayName ?? ''),
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Couldn\'t load this profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => ref.invalidate(userProfileProvider(uid)),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
        data: (profile) => Column(
          children: [
            ProfileHeader(
              user: profile.user,
              trailing: isSelf
                  ? null
                  : SizedBox(
                      width: double.infinity,
                      child: profile.isFollowedByMe
                          ? OutlinedButton(
                              onPressed: () => ref
                                  .read(userProfileProvider(uid).notifier)
                                  .toggleFollow(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: const Text('Following'),
                            )
                          : FilledButton(
                              onPressed: () => ref
                                  .read(userProfileProvider(uid).notifier)
                                  .toggleFollow(),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(40),
                              ),
                              child: const Text('Follow'),
                            ),
                    ),
            ),
            const Divider(height: 1),
            Expanded(child: UserPostsGrid(uid: uid)),
          ],
        ),
      ),
    );
  }
}
