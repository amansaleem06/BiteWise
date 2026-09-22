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
