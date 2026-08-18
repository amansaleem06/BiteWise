import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../restaurants/presentation/providers/restaurant_providers.dart';
import '../providers/profile_providers.dart';
import '../widgets/owned_restaurant_banner.dart';
import '../widgets/profile_widgets.dart';

/// Personal profile. Business owners also get a restaurant banner on top.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final uid = me?.uid;
    final theme = Theme.of(context);
    final restaurantId = me?.ownedRestaurantId?.isNotEmpty == true
        ? me!.ownedRestaurantId
        : me?.pendingClaimRestaurantId;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Profile',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 26,
            letterSpacing: -0.6,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            tooltip: 'Saved',
            onPressed: () => context.push(Routes.saved),
          ),
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
                    if (me?.isBusiness == true &&
                        (restaurantId == null || restaurantId.isEmpty))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Material(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          child: ListTile(
                            title: const Text('Claim your restaurant'),
                            subtitle: const Text(
                              'Match your business to a Maps listing.',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => context.push(Routes.businessSetup),
                          ),
                        ),
                      ),
                    if (restaurantId != null && restaurantId.isNotEmpty)
                      ref
                          .watch(restaurantControllerProvider(restaurantId))
                          .when(
                            loading: () => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              ),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                            data: (restaurant) =>
                                OwnedRestaurantBanner(restaurant: restaurant),
                          ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Latest',
                          style: GoogleFonts.fraunces(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                    Expanded(child: UserPostsGrid(uid: uid)),
                  ],
                ),
              ),
    );
  }
}
