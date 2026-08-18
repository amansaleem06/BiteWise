import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/async_error_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
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
    if (uid == null) return const Scaffold(body: SizedBox.shrink());
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
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
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
                  Text(
                    'TASTEWISE · CULINARY PASSPORT',
                    style: GoogleFonts.sourceSans3(
                      color: AppColors.accentLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
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
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: stats.progressToNext),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: AppColors.cream.withValues(alpha: 0.16),
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
            _StatTile(value: '${stats.postCount}', label: 'Plates shared'),
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.86,
          ),
          itemCount: stats.stamps.length,
          itemBuilder: (context, i) => _Stamp(
            stamp: stats.stamps[i],
            order: i,
          ),
        ),
      ],
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
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One passport stamp — earned stamps pop in with a slight rotation,
/// like a rubber stamp pressed onto the page.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.stamp, required this.order});

  final CuisineStamp stamp;
  final int order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Deterministic tilt per cuisine so the page looks hand-stamped.
    final tilt = ((stamp.cuisine.hashCode % 9) - 4) * (math.pi / 180) * 2;

    final content = Container(
      decoration: BoxDecoration(
        color: stamp.earned
            ? AppColors.accentLight
            : theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: stamp.earned
              ? AppColors.accentDark.withValues(alpha: 0.6)
              : theme.colorScheme.outline.withValues(alpha: 0.5),
          width: stamp.earned ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _cuisineGlyphs[stamp.cuisine] ?? '🍽️',
            style: TextStyle(
              fontSize: 24,
              color: stamp.earned ? null : Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stamp.cuisine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: GoogleFonts.sourceSans3(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: stamp.earned
                  ? AppColors.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (stamp.earned)
            Text(
              '×${stamp.count}',
              style: GoogleFonts.sourceSans3(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.accentDark,
              ),
            ),
        ],
      ),
    );

    if (!stamp.earned) {
      return Opacity(opacity: 0.55, child: content);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + order * 40),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.rotate(
        angle: tilt * t,
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: content,
    );
  }
}
