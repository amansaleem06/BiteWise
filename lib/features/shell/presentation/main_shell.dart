import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

/// Taste Stage: floating seal + rotatable tasting ring (no IG tab bar).
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with SingleTickerProviderStateMixin {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  var _menuOpen = false;
  /// Degrees the ring has been spun by the user.
  var _orbitSpin = 0.0;
  late final AnimationController _fan;

  /// Tasting-menu courses — equal slices on a full circle.
  static const _courses = <_Course>[
    _Course(0, 'Amuse', Icons.auto_awesome_rounded),
    _Course(1, 'Forage', Icons.explore_rounded),
    _Course(2, 'Ember', Icons.local_fire_department_rounded),
    _Course(3, 'Whisper', Icons.forum_rounded),
    _Course(4, 'Cellar', Icons.wine_bar_rounded),
  ];

  static const _radius = 118.0;

  @override
  void initState() {
    super.initState();
    _fan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    Future<void>.microtask(() async {
      try {
        await ref
            .read(pushNotificationServiceProvider)
            .register()
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    if (_menuOpen) {
      _fan.forward();
    } else {
      _fan.reverse();
    }
  }

  void _goCourse(int index) {
    final wasSame = index == navigationShell.currentIndex;
    navigationShell.goBranch(
      index,
      initialLocation: wasSame,
    );
    if (index == 0 && wasSame) {
      ref.read(plateScrollToTopTickProvider.notifier).state++;
    }
    if (_menuOpen) _toggleMenu();
  }

  void _spinBy(double dx) {
    // Horizontal drag → orbit rotation (deg).
    setState(() => _orbitSpin += dx * 0.45);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final index = navigationShell.currentIndex;
    // Lift the whole stage so the ring clears the home indicator & screen edge.
    final stageBottom = bottom + 56;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.48),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: stageBottom,
            child: SizedBox(
              height: _radius * 2 + 72,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: _menuOpen
                    ? (d) => _spinBy(d.delta.dx)
                    : null,
                onPanUpdate: _menuOpen ? (d) => _spinBy(d.delta.dx) : null,
                child: AnimatedBuilder(
                  animation: _fan,
                  builder: (context, _) {
                    final t = Curves.easeOutBack.transform(_fan.value);
                    final r = _radius * t;

                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        // Soft orbit guide when open.
                        if (t > 0.05)
                          Opacity(
                            opacity: (t * 0.35).clamp(0.0, 0.35),
                            child: Container(
                              width: r * 2 + 8,
                              height: r * 2 + 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.35),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        for (var i = 0; i < _courses.length; i++)
                          _orbitChip(
                            course: _courses[i],
                            index: i,
                            selected: index == _courses[i].index,
                            radius: r,
                            opacity: t.clamp(0.0, 1.0),
                          ),
                        // Center seal — always visible, higher on screen.
                        GestureDetector(
                          onTap: _toggleMenu,
                          onLongPress: () => _goCourse(2),
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.brandGradient,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.42),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 3,
                              ),
                            ),
                            child: AnimatedRotation(
                              turns: _menuOpen ? 0.125 : 0,
                              duration: AppDurations.normal,
                              child: Icon(
                                _menuOpen
                                    ? Icons.close_rounded
                                    : Icons.restaurant_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                        if (_menuOpen)
                          Positioned(
                            bottom: 0,
                            child: Text(
                              'Drag to spin the ring',
                              style: GoogleFonts.sourceSans3(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orbitChip({
    required _Course course,
    required int index,
    required bool selected,
    required double radius,
    required double opacity,
  }) {
    // Equal spacing around a full circle; spin shifts the whole ring.
    final slice = 360.0 / _courses.length;
    final degrees = -90 + index * slice + _orbitSpin;
    final angle = degrees * math.pi / 180;
    final dx = math.sin(angle) * radius;
    final dy = -math.cos(angle) * radius;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: _CourseChip(
          label: course.label,
          icon: course.icon,
          selected: selected,
          onTap: () => _goCourse(course.index),
        ),
      ),
    );
  }
}

class _Course {
  const _Course(this.index, this.label, this.icon);
  final int index;
  final String label;
  final IconData icon;
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? AppColors.primary
          : theme.colorScheme.surface.withValues(alpha: 0.96),
      elevation: 8,
      shadowColor: Colors.black45,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: selected
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
