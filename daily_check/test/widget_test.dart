// Basic smoke test for the Daily Check splash screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_check/screens/splash_screen.dart';

void main() {
  testWidgets('Splash screen shows the app name, tagline and version',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );

    // The splash auto-advances, so only pump a single frame rather than
    // settling: the glow and shimmer animations repeat forever.
    expect(find.text('Daily Check'), findsOneWidget);
    expect(find.text('Small daily checks, big lifelong progress.'),
        findsOneWidget);
    expect(find.text('Daily Check v1.0 · Mindful Habit Tracker'),
        findsOneWidget);
  });
}
