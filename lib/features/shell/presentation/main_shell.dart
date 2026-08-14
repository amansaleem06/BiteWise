import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

/// Taste Stage shell: floating orb + radial course menu (no IG tab bar).
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
  late final AnimationController _fan;

  static const _courses = <_Course>[
    _Course(0, 'Plate', Icons.restaurant_menu_rounded, -110),
    _Course(1, 'Atlas', Icons.public_rounded, -55),
    _Course(2, 'Pass', Icons.add_rounded, 0),
    _Course(3, 'Booth', Icons.forum_rounded, 55),
    _Course(4, 'Table', Icons.table_restaurant_rounded, 110),
  ];

  @override
  void initState() {
    super.initState();
    _fan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final index = navigationShell.currentIndex;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: AnimatedOpacity(
                  duration: AppDurations.fast,
                  opacity: _menuOpen ? 1 : 0,
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 12,
            child: SizedBox(
              height: 168,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  ..._courses.map((c) {
                    return AnimatedBuilder(
                      animation: _fan,
                      builder: (context, child) {
                        final t = Curves.easeOutBack.transform(_fan.value);
                        final angle = c.degrees * math.pi / 180;
                        final radius = 96.0 * t;
                        final dx = math.sin(angle) * radius;
                        final dy = -math.cos(angle) * radius * 0.92;
                        return Positioned(
                          bottom: 28 + dy,
                          left: 0,
                          right: 0,
                          child: Opacity(
                            opacity: t.clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(dx, 0),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Center(
                        child: _CourseChip(
                          label: c.label,
                          icon: c.icon,
                          selected: index == c.index,
                          onTap: () => _goCourse(c.index),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: _toggleMenu,
                    onLongPress: () => _goCourse(2),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.brandGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Course {
  const _Course(this.index, this.label, this.icon, this.degrees);
  final int index;
  final String label;
  final IconData icon;
  final double degrees;
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
          : theme.colorScheme.surface.withValues(alpha: 0.95),
      elevation: 6,
      shadowColor: Colors.black38,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
