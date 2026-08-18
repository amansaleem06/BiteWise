import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

/// Taste Stage: maroon seal that opens a horizontal course row.
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final index = navigationShell.currentIndex;
    final stageBottom = bottom > 0 ? bottom + 8 : 14.0;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          if (_menuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                child: ColoredBox(
                  color: AppColors.charcoal.withValues(alpha: 0.42),
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
                          offset: Offset(0, (1 - t) * 18),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.cream.withValues(alpha: 0.96),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.charcoal
                                        .withValues(alpha: 0.16),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    for (final course in _courses)
                                      _CourseChip(
                                        label: course.label,
                                        icon: course.icon,
                                        selected: index == course.index,
                                        onTap: () => _goCourse(course.index),
                                      ),
                                  ],
                                ),
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
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.38),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                            border: Border.all(
                              color: AppColors.cream,
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: AppDurations.fast,
                            child: _menuOpen
                                ? const Icon(
                                    key: ValueKey('close'),
                                    Icons.close_rounded,
                                    color: AppColors.cream,
                                    size: 30,
                                  )
                                : Text(
                                    key: const ValueKey('stage'),
                                    'Stage',
                                    style: GoogleFonts.fraunces(
                                      color: AppColors.cream,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      height: 1,
                                    ),
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.onAccent : AppColors.primary,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.sourceSans3(
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  color: selected ? AppColors.onAccent : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
