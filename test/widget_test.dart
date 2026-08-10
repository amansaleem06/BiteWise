import 'package:bitewise/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('theme builds and renders a frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const Scaffold(body: Center(child: Text('BiteWise'))),
      ),
    );
    expect(find.text('BiteWise'), findsOneWidget);
  });
}
