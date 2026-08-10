import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/brand_mark.dart';

/// Entry screen: brand moment + primary auth choices.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppSnackbar.error(context, userMessageFrom(next.error));
      }
    });

    return AuthScaffold(
      showBack: false,
      children: [
        const SizedBox(height: AppSpacing.xl),
        const BrandMark(size: 88),
        const SizedBox(height: AppSpacing.xs),
        Text(
          AppStrings.tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          AppStrings.welcomeTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.welcomeSubtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: AppStrings.signUp,
          onPressed: () => context.push(Routes.signUp),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppOutlinedButton(
          label: AppStrings.continueWithGoogle,
          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
          isLoading: authState.isLoading,
          onPressed: () =>
              ref.read(authControllerProvider.notifier).signInWithGoogle(),
        ),
        // Sign in with Apple: iOS only (App Review requirement when other
        // third-party sign-ins are offered).
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
          const SizedBox(height: AppSpacing.sm),
          AppOutlinedButton(
            label: AppStrings.continueWithApple,
            icon: const Icon(Icons.apple_rounded, size: 24),
            isLoading: authState.isLoading,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signInWithApple(),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
		Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(AppStrings.hasAccountPrompt,
                style: theme.textTheme.bodyMedium,),
            TextButton(
              onPressed: () => context.push(Routes.signIn),
              child: const Text(AppStrings.signIn),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: () => context.push(Routes.privacyPolicy),
              child: const Text(AppStrings.privacyPolicy),
            ),
            Text('·', style: theme.textTheme.bodySmall),
            TextButton(
              onPressed: () => context.push(Routes.termsOfService),
              child: const Text(AppStrings.termsOfService),
            ),
          ],
        ),
      ],
    );
  }
}
