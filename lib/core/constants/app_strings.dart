/// Centralized user-facing strings.
///
/// Structured for a painless migration to `flutter_localizations` / ARB files
/// when internationalization lands.
abstract final class AppStrings {
  static const appName = 'BiteWise';
  static const tagline = 'Discover. Taste. Share.';

  // Auth
  static const welcomeTitle = 'Every dish has a story';
  static const welcomeSubtitle =
      'Discover restaurants, share food experiences, and follow the tastes you love.';
  static const signIn = 'Sign in';
  static const signUp = 'Create account';
  static const continueWithGoogle = 'Continue with Google';
  static const continueWithApple = 'Continue with Apple';
  static const email = 'Email';
  static const password = 'Password';
  static const confirmPassword = 'Confirm password';
  static const displayName = 'Name';
  static const forgotPassword = 'Forgot password?';
  static const resetPassword = 'Reset password';
  static const resetPasswordSubtitle =
      "Enter your email and we'll send you a link to reset your password.";
  static const resetLinkSent = 'Reset link sent. Check your inbox.';
  static const noAccountPrompt = "Don't have an account?";
  static const hasAccountPrompt = 'Already have an account?';
  static const verifyEmailTitle = 'Verify your email';
  static const verifyEmailSubtitle =
      'We sent a verification link to your email. Tap the link, then come back here.';
  static const resendEmail = 'Resend email';
  static const verificationEmailSent = 'Verification email sent.';
  static const iVerified = "I've verified my email";
  static const signOut = 'Sign out';

  // Settings / legal
  static const settings = 'Settings';
  static const account = 'Account';
  static const legal = 'Legal';
  static const privacyPolicy = 'Privacy Policy';
  static const termsOfService = 'Terms of Service';
  static const deleteAccount = 'Delete account';
  static const deleteAccountTitle = 'Delete your account?';
  static const deleteAccountBody =
      'This permanently deletes your BiteWise account, profile, and personal data. Posts you shared will be anonymized. This cannot be undone.';
  static const deleteAccountConfirm = 'Delete my account';
  static const deleteAccountPasswordHint =
      'Enter your password to confirm.';
  static const accountDeleted = 'Your account has been deleted.';

  // Navigation
  static const navHome = 'Home';
  static const navExplore = 'Explore';
  static const navCreate = 'Create';
  static const navMessages = 'Messages';
  static const navProfile = 'Profile';

  // Generic
  static const comingSoon = 'Coming soon';
  static const retry = 'Retry';
  static const genericError = 'Something went wrong. Please try again.';
}
