import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

/// Taste Stage: floating seal that opens a horizontal course row.
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
    _Course(0, 'Feed', Icons.home_rounded),
    _Course(1, 'Explore', Icons.explore_rounded),
    _Course(2, 'Create', Icons.add_rounded),
    _Course(3, 'Messages', Icons.chat_bubble_rounded),
    _Course(4, 'Profile', Icons.person_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _fan = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
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
    final stageBottom = bottom > 0 ? bottom + 10 : 16.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.45),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: stageBottom,
            child: AnimatedBuilder(
              animation: _fan,
              builder: (context, _) {
                final t = Curves.easeOutCubic.transform(_fan.value);
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t > 0.02)
                      Opacity(
                        opacity: t.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, (1 - t) * 16),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < _courses.length; i++) ...[
                                    if (i > 0) const SizedBox(width: 8),
                                    _CourseChip(
                                      label: _courses[i].label,
                                      icon: _courses[i].icon,
                                      selected: index == _courses[i].index,
                                      onTap: () =>
                                          _goCourse(_courses[i].index),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: GestureDetector(
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 18,
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
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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
