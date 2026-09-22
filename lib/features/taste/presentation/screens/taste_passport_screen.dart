import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/palette_copy.dart';
import '../../domain/taste_stats.dart';
import '../providers/taste_providers.dart';

/// Emoji glyphs for each canonical cuisine stamp.
const _cuisineGlyphs = <String, String>{
  'Asian': '🍜',
  'Italian': '🍝',
  'Hungarian': '🥘',
  'American': '🍔',
  'Mexican': '🌮',
  'Indian': '🍛',
  'Japanese': '🍣',
  'Chinese': '🥟',
  'Thai': '🍤',
  'Mediterranean': '🫒',
  'Middle Eastern': '🧆',
  'Dessert': '🍰',
  'Cafe': '☕',
  'Vegan': '🥗',
  'Seafood': '🦞',
  'Fast Food': '🍟',
};

/// Your culinary journey: level, stats, and one stamp per cuisine tried.
class TastePassportScreen extends ConsumerWidget {
  const TastePassportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final statsAsync = ref.watch(tasteStatsProvider(uid));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Taste Passport',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            letterSpacing: -0.6,
          ),
        ),
      ),
      body: statsAsync.when(
        loading: () => const _PassportSkeleton(),
        error: (error, stack) => AsyncErrorView(
          error: error,
          stackTrace: stack,
          title: 'Couldn\'t open your passport',
          onRetry: () => ref.invalidate(tasteStatsProvider(uid)),
        ),
        data: (stats) => _PassportBody(stats: stats),
      ),
    );
  }
}

class _PassportSkeleton extends StatelessWidget {
  const _PassportSkeleton();

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 144,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: fill,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (var row = 0; row < 2; row++) ...[
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: Container(
                          height: 90,
                          decoration: BoxDecoration(
                            color: fill,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PassportBody extends StatelessWidget {
  const _PassportBody({required this.stats});

  final TasteStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = stats.level.next;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Passport cover.
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.28),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_menu_rounded,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'TASTEWISE · CULINARY PASSPORT',
                            maxLines: 2,
                            style: GoogleFonts.sourceSans3(
                              color: AppColors.accentLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      stats.level.title,
                      style: GoogleFonts.fraunces(
                        color: AppColors.cream,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      next == null
                          ? 'Every cuisine conquered. Take a bow.'
                          : '${next.requiredStamps - stats.earnedStampCount} more '
                              'cuisine${next.requiredStamps - stats.earnedStampCount == 1 ? '' : 's'} '
                              'to reach ${next.title}',
                      style: GoogleFonts.sourceSans3(
                        color: AppColors.cream.withValues(alpha: 0.75),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Semantics(
                      label: next == null
                          ? 'Passport complete'
                          : '${stats.earnedStampCount} of ${next.requiredStamps} cuisines toward ${next.title}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: stats.progressToNext,
                          minHeight: 6,
                          backgroundColor:
                              AppColors.cream.withValues(alpha: 0.16),
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Journey stats.
              Row(
                children: [
                  _StatTile(
                    value: '${stats.postCount}',
                    label: 'Plates shared',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _StatTile(
                    value: '${stats.restaurantIds.length}',
                    label: 'Spots visited',
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _StatTile(
                    value: stats.averageRating == null
                        ? '—'
                        : stats.averageRating!.toStringAsFixed(1),
                    label: 'Avg rating given',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const _DietPlanCard(),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Cuisine stamps  ·  ${stats.earnedStampCount}/${stats.stamps.length}',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tag a cuisine when you post a plate to earn its stamp.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:
                      MediaQuery.textScalerOf(context).scale(1) > 1.3
                          ? AppBreakpoints.gridColumns(
                              context,
                              phone: 2,
                              tablet: 4,
                            )
                          : AppBreakpoints.gridColumns(
                              context,
                              phone: 3,
                              tablet: 5,
                            ),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
                itemCount: stats.stamps.length,
                itemBuilder: (context, i) => _Stamp(stamp: stats.stamps[i]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// AI diet plan entry point — available immediately; tastes can be typed in.
class _DietPlanCard extends StatelessWidget {
  const _DietPlanCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push(Routes.dietPlan),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      PaletteCopy.name,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                PaletteCopy.passportBlurb,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Readable earned and undiscovered cuisine states.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.stamp});

  final CuisineStamp stamp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label:
          '${stamp.cuisine}, ${stamp.earned ? 'earned, ${stamp.count} plates' : 'not yet discovered'}',
      child: Container(
        decoration: BoxDecoration(
          color: stamp.earned
              ? AppColors.accentLight
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color:
                stamp.earned ? AppColors.accentDark : theme.colorScheme.outline,
            width: stamp.earned ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    stamp.earned ? AppColors.cream : theme.colorScheme.surface,
                border: Border.all(
                  color: stamp.earned
                      ? AppColors.accentDark
                      : theme.colorScheme.outline,
                ),
              ),
              child: Text(
                _cuisineGlyphs[stamp.cuisine] ?? '🍽️',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              stamp.cuisine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.sourceSans3(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: stamp.earned
                    ? AppColors.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (stamp.earned)
              Text(
                '×${stamp.count}',
                style: GoogleFonts.sourceSans3(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentDark,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
