import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart' as app_providers;
import 'screens/splash_screen.dart';
import 'services/services.dart';

/// Top-level entry point.
///
/// Wires up the services (storage, notifications, day-reset) and runs
/// the Riverpod-scoped [App].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize persistent storage. This is the only one that needs to
  //    finish before the UI is shown, because all other providers depend
  //    on it.
  app_providers.storage = await StorageService.init();

  // 2. Initialize notifications. We start the service early so we can
  //    re-schedule existing tasks before the user lands on the home screen.
  final notif = NotificationService();
  await notif.init();
  app_providers.notifications = notif;

  // 3. Start the day-reset watcher. It will re-schedule notifications and
  //    refresh state on the next minute boundary.
  final dayReset = DayResetService(
    storage: app_providers.storage,
    notifications: notif,
  );
  dayReset.start();
  app_providers.dayReset = dayReset;

  runApp(
    ProviderScope(
      child: _NotificationsObserver(child: const App()),
    ),
  );
}

/// Re-evaluates the day-reset service whenever the app comes back to
/// foreground. This catches missed midnight rollovers even if the
/// timer drift accumulated while the app was suspended.
class _NotificationsObserver extends ConsumerStatefulWidget {
  final Widget child;
  const _NotificationsObserver({required this.child});

  @override
  ConsumerState<_NotificationsObserver> createState() =>
      _NotificationsObserverState();
}

class _NotificationsObserverState extends ConsumerState<_NotificationsObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      app_providers.dayReset.forceCheck();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The root widget. Sets up Material 3 theming and the app shell.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Daily Check',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    // Mindful Habit Track Design System Colors
    const primary = Color(0xFFE85D30);        // Burnt coral
    const secondary = Color(0xFFFF8A65);      // Soft peach
    const tertiary = Color(0xFFFFEDE6);       // Pale peach
    const surfaceCanvas = Color(0xFFF9F7F4);  // Warm bone/cream
    const surfaceCard = Color(0xFFFFFFFF);   // Pure white
    const textHigh = Color(0xFF1F2429);      // Charcoal
    const textMedium = Color(0xFF4B5563);    // Neutral gray
    const borderOutline = Color(0xFFE5E0D8); // Warm outline

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surfaceCard,
      onSurface: textHigh,
      surfaceContainerHighest: const Color(0xFFF2EBE5),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: surfaceCanvas,
      fontFamily: 'Manrope',
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceCanvas,
        foregroundColor: textHigh,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Outfit',
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textHigh,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: surfaceCard,
        shadowColor: const Color(0x0A1F2429),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF3EFEA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceCard,
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF9CA3AF),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}