// Basic smoke test for the Daily Check splash screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_check/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows app name and Get Started button',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );

    expect(find.text('Daily Check'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Small daily checks,\nBig lifelong progress'),
        findsOneWidget);
  });
}
