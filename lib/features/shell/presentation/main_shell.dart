import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/theme_mode_provider.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

/// Floating menu seal that opens a horizontal course row.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  var _menuOpen = false;
  late final AnimationController _fan;

  static const _courses = <_Course>[
    _Course(0, 'Feed', Icons.home_outlined),
    _Course(1, 'Explore', Icons.explore_outlined),
    _Course(2, 'Create', Icons.add_rounded),
    _Course(3, 'Messages', Icons.chat_bubble_outline_rounded),
    _Course(4, 'Profile', Icons.person_outline_rounded),
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
      // Pending restaurant claims stay pending until support approves them.
    });
  }

  @override
  void dispose() {
    _fan.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() => _menuOpen = !_menuOpen);
    if (MediaQuery.disableAnimationsOf(context)) {
      _fan.value = _menuOpen ? 1 : 0;
      return;
    }
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

    if (index != 0 && _menuOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_menuOpen) _toggleMenu();
      });
    }

    return PopScope(
      canPop: !_menuOpen && index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_menuOpen) {
          _toggleMenu();
        } else if (index != 0) {
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: navigationShell),
            if (index == 0 && _menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _toggleMenu,
                  child: AnimatedOpacity(
                    duration: AppDurations.fast,
                    opacity: 1,
                    child: ColoredBox(
                      color: AppColors.charcoal.withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
            if (index == 0)
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
                              offset: Offset(0, (1 - t) * 14),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 14),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.cream.withValues(alpha: 0.97),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.pill),
                                    border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.08),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.charcoal
                                            .withValues(alpha: 0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      children: [
                                        for (final course in _courses)
                                          _CourseChip(
                                            label: course.label,
                                            icon: course.icon,
                                            selected: index == course.index,
                                            onTap: () =>
                                                _goCourse(course.index),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Center(
                          child: Semantics(
                            button: true,
                            label: _menuOpen
                                ? 'Close navigation'
                                : 'Open navigation',
                            child: GestureDetector(
                              onTap: _toggleMenu,
                              onLongPress: () => _goCourse(2),
                              child: Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primary,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.22),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  border: Border.all(
                                    color:
                                        AppColors.cream.withValues(alpha: 0.9),
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: AnimatedSwitcher(
                                  duration:
                                      MediaQuery.disableAnimationsOf(context)
                                          ? Duration.zero
                                          : AppDurations.fast,
                                  child: Icon(
                                    _menuOpen
                                        ? Icons.close_rounded
                                        : Icons.restaurant_menu_rounded,
                                    key: ValueKey(_menuOpen),
                                    color: AppColors.cream,
                                    size: 26,
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
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppDurations.fast,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sourceSans3(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 10,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
