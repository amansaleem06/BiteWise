import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_legal.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/contact_support.dart';

/// How to reach TasteWise support, including after a report.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.support)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          Text(
            'Reach TasteWise',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'For reports, account help, or anything else, email Aman directly. This is the same inbox used for App Store support.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.mail_outline_rounded),
            title: const Text('Email support'),
            subtitle: const Text(AppLegal.supportEmail),
            onTap: () => ContactSupport.email(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_rounded),
            title: const Text('Copy email address'),
            onTap: () => ContactSupport.copyEmail(context),
          ),
          const Divider(height: 32),
          Text('Report or block someone', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'On a post, tap the ••• menu, then Report post or Block user.\n'
            'On a profile or chat, tap ••• in the top-right.\n'
            'On a story that is not yours, tap ••• next to the progress bar.\n'
            'On a comment, tap Report.\n\n'
            'Reports are saved for review. Email ${AppLegal.supportEmail} if you need a faster reply.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
