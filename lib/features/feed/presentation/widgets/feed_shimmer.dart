import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';

/// Lightweight skeleton loader for the feed (no external shimmer package —
/// a simple pulse keeps the dependency tree lean).
class FeedShimmer extends StatefulWidget {
  const FeedShimmer({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  State<FeedShimmer> createState() => _FeedShimmerState();
}

class _FeedShimmerState extends State<FeedShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.35,
    upperBound: 0.7,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return FadeTransition(
      opacity: _controller,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: widget.itemCount,
        itemBuilder: (_, __) => _SkeletonCard(
          color: base.withValues(alpha: 0.08),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h, {double r = AppRadius.sm}) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(r),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                box(36, 36, r: AppRadius.pill),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    box(120, 12),
                    const SizedBox(height: 6),
                    box(80, 10),
                  ],
                ),
              ],
            ),
          ),
          AspectRatio(aspectRatio: 1.2, child: Container(color: color)),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: box(200, 12),
          ),
        ],
      ),
    );
  }
}
