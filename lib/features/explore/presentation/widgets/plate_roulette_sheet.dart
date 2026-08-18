import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../restaurants/domain/entities/restaurant.dart';
import '../providers/explore_providers.dart';
import 'nearby_map_tab.dart';

/// "Can't decide?" — spin a wheel of nearby (or top-rated) restaurants.
class PlateRouletteSheet extends ConsumerStatefulWidget {
  const PlateRouletteSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const PlateRouletteSheet(),
    );
  }

  @override
  ConsumerState<PlateRouletteSheet> createState() => _PlateRouletteSheetState();
}

class _PlateRouletteSheetState extends ConsumerState<PlateRouletteSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  final _random = math.Random();

  List<Restaurant> _wheel = const [];
  Restaurant? _winner;
  double _fromAngle = 0;
  double _toAngle = 0;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _spinning = false);
        }
      });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_spinning || _wheel.isEmpty) return;
    final winnerIndex = _random.nextInt(_wheel.length);
    final wedge = 2 * math.pi / _wheel.length;
    // The pointer sits at the top (12 o'clock = -pi/2 in canvas space).
    // Rotate so the middle of the winning wedge lands under the pointer,
    // plus 4–6 full turns for drama.
    final winnerCenter = winnerIndex * wedge + wedge / 2;
    final target = -math.pi / 2 - winnerCenter;
    final turns = 4 + _random.nextInt(3);
    setState(() {
      _winner = _wheel[winnerIndex];
      _fromAngle = _toAngle % (2 * math.pi);
      _toAngle = target - turns * 2 * math.pi;
      _spinning = true;
    });
    _spin
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nearbyAsync = ref.watch(nearbyProvider);
    final topRatedAsync = ref.watch(topRatedRestaurantsProvider);

    if (nearbyAsync.isLoading && topRatedAsync.isLoading) {
      return const SizedBox(
        height: 320,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
      );
    }

    final nearby = nearbyAsync.valueOrNull;
    final topRated = topRatedAsync.valueOrNull;
    final source = (nearby?.restaurants.isNotEmpty ?? false)
        ? nearby!.restaurants
        : (topRated ?? const <Restaurant>[]);
    _wheel = source.take(8).toList();
    final usingNearby = nearby?.restaurants.isNotEmpty ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Plate Roulette',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _wheel.isEmpty
                ? 'No restaurants to spin yet — post a plate to put spots on the wheel.'
                : usingNearby
                    ? 'Fate picks from ${_wheel.length} spots near you.'
                    : 'Fate picks from the ${_wheel.length} top-rated spots.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_wheel.isNotEmpty) ...[
            SizedBox(
              width: 280,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 20,
                    child: AnimatedBuilder(
                      animation: _spin,
                      builder: (context, _) {
                        final t =
                            Curves.easeOutQuart.transform(_spin.value);
                        final angle =
                            _fromAngle + (_toAngle - _fromAngle) * t;
                        return Transform.rotate(
                          angle: angle,
                          child: CustomPaint(
                            size: const Size(260, 260),
                            painter: _WheelPainter(
                              names: [for (final r in _wheel) r.name],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Pointer.
                  const Positioned(
                    top: 0,
                    child: Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                  // Hub.
                  Positioned(
                    top: 20 + 130 - 22,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: AppColors.cream, width: 3),
                      ),
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: AppColors.cream,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: (!_spinning && _winner != null)
                  ? _WinnerCard(
                      key: ValueKey(_winner!.id),
                      restaurant: _winner!,
                    )
                  : const SizedBox(height: 8),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _spinning ? null : _startSpin,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.casino_outlined),
              label: Text(
                _spinning
                    ? 'Spinning…'
                    : _winner == null
                        ? 'Spin the wheel'
                        : 'Spin again',
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Icon(
                Icons.casino_outlined,
                size: 56,
                color: AppColors.accentDark,
              ),
            ),
        ],
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({super.key, required this.restaurant});

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = restaurant.averageRating;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.accentDark.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            'Tonight you\'re eating at',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            restaurant.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          if (rating != null) ...[
            const SizedBox(height: 2),
            Text(
              '★ ${rating.toStringAsFixed(1)} on TasteWise',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push(Routes.restaurantPath(restaurant.id));
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Take me there'),
          ),
        ],
      ),
    );
  }
}

/// Alternating maroon / champagne wedges with restaurant names.
class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.names});

  final List<String> names;

  static const _wedgeColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.primaryDark,
    AppColors.accentDark,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final wedge = 2 * math.pi / names.length;

    for (var i = 0; i < names.length; i++) {
      final paint = Paint()
        ..color = _wedgeColors[i % _wedgeColors.length];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * wedge,
        wedge,
        true,
        paint,
      );
    }

    // Rim.
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.cream,
    );

    // Names along each wedge.
    for (var i = 0; i < names.length; i++) {
      final angle = i * wedge + wedge / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final label = names[i].length > 14
          ? '${names[i].substring(0, 13)}…'
          : names[i];
      // The champagne wedge needs dark text for contrast.
      final onWedge =
          i % _wedgeColors.length == 1 ? AppColors.primaryDark : AppColors.cream;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: onWedge,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: radius - 40);
      painter.paint(canvas, Offset(radius * 0.32, -painter.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.names != names;
}
