import 'package:bitewise/features/auth/presentation/widgets/terms_acceptance.dart';
import 'package:bitewise/features/auth/presentation/providers/consent_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('terms start unchecked and require explicit consent',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TermsAcceptance())),
      ),
    );
    expect(container.read(termsCheckedProvider), false);
    expect(find.text('Terms of Use / EULA'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(container.read(termsCheckedProvider), true);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(container.read(termsCheckedProvider), false);
  });

  testWidgets('compact auth notice links legal documents without a checkbox',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LegalConsentNotice())),
    );

    expect(find.textContaining('By continuing'), findsOneWidget);
    expect(find.text('Terms of Use / EULA'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });
}
