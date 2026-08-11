import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/profile_widgets.dart';

/// Own profile tab: header + posts grid + settings.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          ref.watch(currentUserProvider)?.displayName ?? AppStrings.navProfile,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Reservations',
            onPressed: () => context.push(Routes.reservations),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: AppStrings.settings,
            onPressed: () => context.push(Routes.settings),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : ref.watch(userProfileProvider(uid)).when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                error: (error, stack) => AsyncErrorView(
                  error: error,
                  stackTrace: stack,
                  title: 'Couldn\'t load profile',
                  onRetry: () => ref.invalidate(userProfileProvider(uid)),
                ),
                data: (profile) => Column(
                  children: [
                    ProfileHeader(
                      user: profile.user,
                      trailing: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => context.push(Routes.editProfile),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(40),
                          ),
                          child: const Text('Edit profile'),
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
