import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/theme_mode_provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/errors/error_text.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Account & legal settings — includes App Store–required account deletion.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        AppSnackbar.error(context, userMessageFrom(next.error));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        children: [
          const _SectionHeader(AppStrings.account),
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: const Text('Edit profile'),
            onTap: () => context.push(Routes.editProfile),
          ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: Text(_appearanceLabel(ref.watch(themeModeProvider))),
            onTap: () => _pickAppearance(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_outline_rounded),
            title: const Text('Saved plates'),
            onTap: () => context.push(Routes.saved),
          ),
          ListTile(
            leading: authState.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            title: const Text(AppStrings.signOut),
            enabled: !authState.isLoading,
            onTap: () async {
              try {
                await ref.read(authControllerProvider.notifier).signOut();
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.error(context, userMessageFrom(e));
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
            title: Text(
              AppStrings.deleteAccount,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: AppColors.error),
            ),
            enabled: !authState.isLoading,
            onTap: () => _confirmDeleteAccount(context, ref),
          ),
          const Divider(height: 32),
          const _SectionHeader(AppStrings.legal),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text(AppStrings.privacyPolicy),
            onTap: () => context.push(Routes.privacyPolicy),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text(AppStrings.termsOfService),
            onTap: () => context.push(Routes.termsOfService),
          ),
          const SizedBox(height: AppSpacing.xl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              '${AppStrings.appName} · ${AppStrings.tagline}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteAccountTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.deleteAccountBody),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: AppStrings.password,
                hintText: AppStrings.deleteAccountPasswordHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              AppStrings.deleteAccountConfirm,
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    final password = passwordController.text;
    passwordController.dispose();
    if (confirmed != true || !context.mounted) return;

    final ok = await ref.read(authControllerProvider.notifier).deleteAccount(
          password: password.isEmpty ? null : password,
        );
    if (ok && context.mounted) {
      AppSnackbar.success(context, AppStrings.accountDeleted);
    }
  }

  static String _appearanceLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  Future<void> _pickAppearance(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);
    final chosen = await showModalBottomSheet<ThemeMode>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in ThemeMode.values)
              ListTile(
                title: Text(_appearanceLabel(mode)),
                trailing: mode == current
                    ? const Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, mode),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await ref.read(themeModeProvider.notifier).setMode(chosen);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
