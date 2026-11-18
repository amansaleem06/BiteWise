import 'package:bitewise/features/auth/domain/entities/app_user.dart';
import 'package:bitewise/features/profile/presentation/widgets/profile_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('compact profile fits a small phone at text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(scale),
            ),
            child: const Scaffold(
              body: SingleChildScrollView(
                child: ProfileHeader(
                  plateInspired: true,
                  user: AppUser(
                    uid: 'person',
                    email: 'person@example.com',
                    displayName: 'A long profile display name',
                    role: UserRole.user,
                    bio: 'Food and friends.',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('Posts'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.text('Following'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
