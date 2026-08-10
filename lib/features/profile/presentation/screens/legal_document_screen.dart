import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_legal.dart';
import '../../../../core/constants/app_strings.dart';

/// Simple offline legal document viewer (Privacy / Terms).
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen.privacy({super.key})
      : title = AppStrings.privacyPolicy,
        body = AppLegal.privacyPolicyMarkdown;

  const LegalDocumentScreen.terms({super.key})
      : title = AppStrings.termsOfService,
        body = AppLegal.termsOfServiceMarkdown;

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = body.trim().split('\n');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          if (line.startsWith('# ')) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                line.substring(2),
                style: theme.textTheme.headlineSmall,
              ),
            );
          }
          if (line.startsWith('## ')) {
            return Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Text(
                line.substring(3),
                style: theme.textTheme.titleMedium,
              ),
            );
          }
          if (line.isEmpty) return const SizedBox(height: AppSpacing.sm);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(line, style: theme.textTheme.bodyMedium),
          );
        },
      ),
    );
  }
}
