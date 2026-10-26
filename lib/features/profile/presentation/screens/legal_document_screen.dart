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
            // The app bar already names the document; don't repeat it in the
            // document body.
            if (line.substring(2).trim() == title) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _formattedText(
                line.substring(2),
                theme.textTheme.headlineSmall,
              ),
            );
          }
          if (line.startsWith('## ')) {
            return Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: _formattedText(
                line.substring(3),
                theme.textTheme.titleMedium,
              ),
            );
          }
          if (line.isEmpty) return const SizedBox(height: AppSpacing.sm);
          if (line.startsWith('- ')) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('-', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _formattedText(
                      line.substring(2),
                      theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _formattedText(line, theme.textTheme.bodyMedium),
          );
        },
      ),
    );
  }

  Widget _formattedText(String text, TextStyle? style) {
    final spans = <InlineSpan>[];
    final bold = RegExp(r'\*\*(.+?)\*\*');
    var offset = 0;
    for (final match in bold.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: style?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    return SelectableText.rich(
      TextSpan(style: style, children: spans),
    );
  }
}
