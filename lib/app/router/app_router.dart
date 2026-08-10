import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/auth/presentation/screens/welcome_screen.dart';
import '../../features/comments/presentation/screens/post_detail_screen.dart';
import '../../features/create/presentation/screens/create_screen.dart';
import '../../features/explore/presentation/screens/explore_screen.dart';
import '../../features/explore/presentation/screens/search_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/chat_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/legal_document_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/profile/presentation/screens/user_profile_screen.dart';
import '../../features/reservations/presentation/screens/my_reservations_screen.dart';
import '../../features/restaurants/presentation/screens/restaurant_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import 'routes.dart';

/// Bridges a [Stream] to [Listenable] so GoRouter re-evaluates redirects
/// whenever auth state changes.
class _StreamListenable extends ChangeNotifier {
  _StreamListenable(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshListenable = _StreamListenable(
    ref.watch(authRepositoryProvider).authStateChanges(),
  );
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      // While auth state is loading, stay put (splash handles first frame).
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final loc = state.matchedLocation;
      final onAuthScreen = loc == Routes.welcome ||
          loc == Routes.signIn ||
          loc == Routes.signUp ||
          loc == Routes.forgotPassword;
      final onLegalScreen =
          loc == Routes.privacyPolicy || loc == Routes.termsOfService;

      if (user == null) {
        if (onAuthScreen || onLegalScreen) return null;
        return Routes.welcome;
      }

      // Email verification is not required — signed-in users go straight in.
      if (onAuthScreen || loc == Routes.verifyEmail) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.welcome,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(path: Routes.signIn, builder: (_, __) => const SignInScreen()),
      GoRoute(path: Routes.signUp, builder: (_, __) => const SignUpScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.verifyEmail,
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      // Full-screen detail pages (pushed above the shell).
      GoRoute(
        path: Routes.restaurant,
        builder: (_, state) =>
            RestaurantScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.post,
        builder: (_, state) =>
            PostDetailScreen(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.user,
        builder: (_, state) =>
            UserProfileScreen(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: Routes.editProfile,
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.privacyPolicy,
        builder: (_, __) => const LegalDocumentScreen.privacy(),
      ),
      GoRoute(
        path: Routes.termsOfService,
        builder: (_, __) => const LegalDocumentScreen.terms(),
      ),
      GoRoute(
        path: Routes.search,
        builder: (_, __) => const SearchScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: Routes.chat,
        builder: (_, state) =>
            ChatScreen(chatId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.reservations,
        builder: (_, __) => const MyReservationsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, __) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.explore,
                builder: (_, __) => const ExploreScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.create,
                builder: (_, __) => const CreateScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.messages,
                builder: (_, __) => const MessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
