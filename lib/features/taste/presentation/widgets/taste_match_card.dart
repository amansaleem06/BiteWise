import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/taste_stats.dart';
import '../providers/taste_providers.dart';

/// Compatibility strip shown on another user's profile.
///
/// Renders nothing while loading, on error, or when either side has no
/// posts yet — the profile stays clean instead of showing a broken score.
class TasteMatchCard extends ConsumerWidget {
  const TasteMatchCard({super.key, required this.uid, required this.name});

  final String uid;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = ref.watch(tasteMatchProvider(uid)).valueOrNull;
    if (match == null || !match.hasEnoughData) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final verdict = switch (match.percent) {
      >= 75 => 'Practically taste twins',
      >= 50 => 'You\'d share a table well',
      >= 25 => 'Some delicious overlap',
      _ => 'Opposites — trade recommendations!',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Material(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => _showBreakdown(context, match),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                _PercentRing(percent: match.percent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taste Match',
                        style: GoogleFonts.sourceSans3(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.accentDark,
                        ),
                      ),
                      Text(
                        verdict,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.accentDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBreakdown(BuildContext context, TasteMatch match) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _PercentRing(percent: match.percent, size: 56),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'You & $name',
                        style: GoogleFonts.fraunces(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                if (match.sharedCuisines.isNotEmpty) ...[
                  Text('Cuisines you both love',
                      style: theme.textTheme.titleSmall,),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in match.sharedCuisines)
                        Chip(
                          label: Text(c),
                          labelStyle: GoogleFonts.sourceSans3(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          backgroundColor: AppColors.accentLight,
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (match.sharedRestaurants.isNotEmpty) ...[
                  Text('Spots you\'ve both plated',
                      style: theme.textTheme.titleSmall,),
                  const SizedBox(height: AppSpacing.xs),
                  for (final r in match.sharedRestaurants.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            size: 16,
                            color: AppColors.accentDark,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              r,
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (match.sharedCuisines.isEmpty &&
                    match.sharedRestaurants.isEmpty)
                  Text(
                    'No overlap yet — one of you should pick the next dinner '
                    'spot and convert the other.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                Text(
                  'Computed from the cuisines you tag, the spots you post '
                  'from, and how you both rate.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PercentRing extends StatelessWidget {
  const _PercentRing({required this.percent, this.size = 44});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: percent / 100),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: value,
              strokeWidth: 4,
              backgroundColor: AppColors.accentDark.withValues(alpha: 0.2),
              color: AppColors.primary,
            ),
            Text(
              '${(value * 100).round()}%',
              style: GoogleFonts.sourceSans3(
                fontSize: size * 0.26,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
