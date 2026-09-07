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
          Text('Common questions', style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          const _Faq(
            question: 'How do I claim my restaurant?',
            answer:
                'Create a business account, match the Google Maps listing, then upload a storefront or license photo and email the claim code to support. We mark Verified Owner after that review.',
          ),
          const _Faq(
            question: 'How do I report or block someone?',
            answer:
                'On a post, tap ••• then Report or Block. The same menu is on profiles, chats, stories, and comments.',
          ),
          const _Faq(
            question: 'Where are my saved plates?',
            answer:
                'Profile → Settings → Saved plates, or the bookmark icon on any post.',
          ),
          const _Faq(
            question: 'Can I delete my account?',
            answer:
                'Yes. Settings → Delete account. Your profile is removed and posts are anonymized.',
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

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
      title: Text(question),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            answer,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}
