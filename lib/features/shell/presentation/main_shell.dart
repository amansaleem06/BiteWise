import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../notifications/presentation/providers/notification_providers.dart';

/// App scaffold with bottom navigation hosting the five main tabs.
///
/// Uses [StatefulNavigationShell] so each tab keeps its own navigation
/// stack and scroll position. Also owns the FCM registration lifecycle —
/// this widget only exists while a verified user is signed in.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StatefulNavigationShell get navigationShell => widget.navigationShell;

  @override
  void initState() {
    super.initState();
    // Register this device for push — never block the shell on FCM.
    Future<void>.microtask(() async {
      try {
        await ref
            .read(pushNotificationServiceProvider)
            .register()
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // Permission denial / missing APNs must not freeze the app.
      }
    });
  }

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      // Re-tapping the active tab pops to its root (standard app behavior).
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: AppStrings.navHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore_rounded),
            label: AppStrings.navExplore,
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: AppStrings.navCreate,
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: AppStrings.navMessages,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: AppStrings.navProfile,
          ),
        ],
      ),
    );
  }
}
