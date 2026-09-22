import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/routes.dart';
import '../providers/consent_providers.dart';

class TermsAcceptance extends ConsumerWidget {
  const TermsAcceptance({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        children: [
          CheckboxListTile(
            value: ref.watch(termsCheckedProvider),
            onChanged: (value) =>
                ref.read(termsCheckedProvider.notifier).state = value ?? false,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I agree to the Terms of Use / EULA'),
            subtitle: const Text(
                'Zero tolerance for objectionable content and abusive behavior. I have read the Privacy Policy.'),
          ),
          Wrap(
            children: [
              TextButton(
                  onPressed: () => context.push(Routes.termsOfService),
                  child: const Text('Terms of Use / EULA')),
              TextButton(
                  onPressed: () => context.push(Routes.privacyPolicy),
                  child: const Text('Privacy Policy')),
            ],
          ),
        ],
      );
}

/// Compact acknowledgement for public authentication screens.
///
/// Continuing with an authentication action records the current terms version.
/// The checkbox-based widget above is reserved for the dedicated re-consent
/// screen when a signed-in account is missing the current version.
class LegalConsentNotice extends StatelessWidget {
  const LegalConsentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactButtonStyle = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: theme.textTheme.bodySmall?.copyWith(
        decoration: TextDecoration.underline,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to our Terms of Use / EULA and acknowledge our Privacy Policy.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton(
              style: compactButtonStyle,
              onPressed: () => context.push(Routes.termsOfService),
              child: const Text('Terms of Use / EULA'),
            ),
            TextButton(
              style: compactButtonStyle,
              onPressed: () => context.push(Routes.privacyPolicy),
              child: const Text('Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }
}
