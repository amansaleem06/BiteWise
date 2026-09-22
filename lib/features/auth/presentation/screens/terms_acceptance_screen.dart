import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/error_text.dart';
import '../providers/auth_providers.dart';
import '../providers/consent_providers.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/terms_acceptance.dart';

class TermsAcceptanceScreen extends ConsumerWidget {
  const TermsAcceptanceScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(termsAcceptedProvider);
    final action = ref.watch(authControllerProvider);
    return AuthScaffold(
      showBack: false,
      children: [
        Text(
          'Before you continue',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Text(
          'Please review and accept our community terms to use TasteWise.',
        ),
        const TermsAcceptance(),
        if (consent.isLoading || action.isLoading)
          const Center(child: CircularProgressIndicator()),
        if (consent.hasError) ...[
          const Text(
            'We could not check your agreement. Check your connection and retry.',
          ),
          TextButton(
            onPressed: () => ref.invalidate(termsAcceptedProvider),
            child: const Text('Retry'),
          ),
        ],
        if (action.hasError) Text(userMessageFrom(action.error)),
        FilledButton(
          onPressed: !action.isLoading && ref.watch(termsCheckedProvider)
              ? () => ref.read(authControllerProvider.notifier).acceptTerms()
              : null,
          child: const Text('Agree and continue'),
        ),
        TextButton(
          onPressed: action.isLoading
              ? null
              : () => ref.read(authControllerProvider.notifier).signOut(),
          child: const Text('Sign out'),
        ),
      ],
    );
  }
}
