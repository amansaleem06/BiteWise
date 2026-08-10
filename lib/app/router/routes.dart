/// Route path constants — the single source of truth for navigation targets.
abstract final class Routes {
  // Auth
  static const welcome = '/welcome';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const verifyEmail = '/verify-email';

  // Details
  static const restaurant = '/restaurant/:id';
  static String restaurantPath(String id) => '/restaurant/$id';
  static const post = '/post/:id';
  static String postPath(String id) => '/post/$id';
  static const user = '/user/:uid';
  static String userPath(String uid) => '/user/$uid';
  static const editProfile = '/profile/edit';
  static const settings = '/settings';
  static const privacyPolicy = '/privacy';
  static const termsOfService = '/terms';
  static const search = '/search';
  static const notifications = '/notifications';
  static const chat = '/chat/:id';
  static String chatPath(String id) => '/chat/$id';
  static const reservations = '/reservations';

  // Shell tabs
  static const home = '/home';
  static const explore = '/explore';
  static const create = '/create';
  static const messages = '/messages';
  static const profile = '/profile';
}
