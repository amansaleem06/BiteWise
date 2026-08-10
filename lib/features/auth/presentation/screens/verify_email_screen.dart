import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../providers/auth_providers.dart';
import '../widgets/auth_scaffold.dart';

/// Shown after email sign-up until the user verifies their address.
///
/// Polls every few seconds so the user is moved forward automatically the
/// moment they tap the link — no manual refresh required.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking) return;
    _checking = true;
    final verified =
        await ref.read(authControllerProvider.notifier).checkVerified();
    _checking = false;
    // On success the auth stream re-emits and the router redirects to Home.
    if (!verified && manual && mounted) {
      AppSnackbar.show(context, 'Not verified yet — check your inbox.');
    }
  }

  Future<void> _resend() async {
    final ok =
        await ref.read(authControllerProvider.notifier).resendVerification();
    if (ok && mounted) {
      AppSnackbar.success(context, AppStrings.verificationEmailSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = ref.watch(currentUserProvider)?.email ?? '';

    return AuthScaffold(
      showBack: false,
      children: [
        Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_unread_outlined,
            size: 44,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          AppStrings.verifyEmailTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${AppStrings.verifyEmailSubtitle}\n$email',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: AppStrings.iVerified,
          onPressed: () => _check(manual: true),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppOutlinedButton(label: AppStrings.resendEmail, onPressed: _resend),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () =>
              ref.read(authControllerProvider.notifier).signOut(),
          child: const Text(AppStrings.signOut),
        ),
      ],
    );
  }
}
