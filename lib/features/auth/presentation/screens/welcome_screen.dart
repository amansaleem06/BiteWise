import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/brand_mark.dart';
import '../widgets/terms_acceptance.dart';

/// Entry screen with a simple provider-first sign-in choice.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final session = ref.watch(authStateProvider);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppSnackbar.error(context, userMessageFrom(next.error));
      }
    });

    // Wait for Firebase's persisted session/profile lookup before presenting
    // sign-in actions, so startup cannot flash a false signed-out state.
    if (session.isLoading) {
      return Theme(
        data: AppTheme.light,
        child: const Scaffold(
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.authBackground),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.authBackground),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.xl),
                          const BrandMark(size: 82),
                          const SizedBox(height: AppSpacing.xxl),
                          Text(
                            'Sign up or log in to TasteWise',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              height: 1.12,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          if (!kIsWeb &&
                              defaultTargetPlatform == TargetPlatform.iOS) ...[
                            AppOutlinedButton(
                              label: AppStrings.continueWithApple,
                              icon: const Icon(Icons.apple_rounded, size: 24),
                              isLoading: authState.isLoading,
                              onPressed: () => ref
                                  .read(authControllerProvider.notifier)
                                  .signInWithApple(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          AppOutlinedButton(
                            label: AppStrings.continueWithGoogle,
                            icon: const Icon(
                              Icons.g_mobiledata_rounded,
                              size: 28,
                            ),
                            isLoading: authState.isLoading,
                            onPressed: () => ref
                                .read(authControllerProvider.notifier)
                                .signInWithGoogle(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppButton(
                            label: 'Continue with email',
                            icon: const Icon(Icons.email_outlined, size: 20),
                            onPressed: () => context.push(Routes.signIn),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          const LegalConsentNotice(),
                          const SizedBox(height: AppSpacing.md),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
