import 'dart:async';

import 'package:flutter/material.dart';

import 'app_shell.dart';
import '../widgets/responsive_center.dart';

/// The splash / launch screen.
///
/// Warm off-white canvas with a soft ambient peach glow, a glowing coral
/// squircle app icon with a checkmark and a floating "🔥 Active" streak
/// badge, "Daily Check" title in Outfit, a tagline, a row of step dots, and
/// a shimmering loading bar that auto-advances into the app — matches the
/// Stitch "Daily Check - Splash Screen" design.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  Timer? _navTimer;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 4000))..repeat(reverse: true);
    _navTimer = Timer(const Duration(milliseconds: 1600), _goToHome);
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _glow.dispose();
    super.dispose();
  }

  void _goToHome() {
    if (_navigating || !mounted) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stitch "Daily Check - Splash Screen" tokens
    const surface = Color(0xFFF8F9FA);
    const primary = Color(0xFFE85D30);
    const brand = Color(0xFFFF7B54);
    const peachLight = Color(0xFFFFE2D7);
    const charcoal = Color(0xFF1E232A);
    const muted = Color(0xFF7E8691);

    return GestureDetector(
      onTap: _goToHome,
      child: Scaffold(
        backgroundColor: surface,
        body: Stack(
          children: [
            // Ambient radial glow behind the hero, mirroring the Stitch design.
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.3),
                      radius: 0.55,
                      colors: [
                        Color(0xA6FFDBCC),
                        Color(0x59FFEEE6),
                        Color(0x00F8F9FA),
                      ],
                      stops: [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ResponsiveCenter(
                maxWidth: 480,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 3),

                      // Squircle app icon with pulsing halo + streak badge
                      Center(
                        child: _AppIcon(glow: _glow, primary: primary, brand: brand, peachLight: peachLight),
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'Daily Check',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: charcoal,
                          letterSpacing: -0.9,
                          height: 1.2,
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Small daily checks, big lifelong progress.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: muted,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Step dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Dot(color: primary),
                          const SizedBox(width: 8),
                          _Dot(color: primary.withValues(alpha: 0.4)),
                          const SizedBox(width: 8),
                          _Dot(color: primary.withValues(alpha: 0.2)),
                        ],
                      ),

                      const Spacer(flex: 4),

                      // Shimmering loading bar
                      Center(
                        child: _LoadingBar(primary: primary, brand: brand),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Daily Check v1.0 · Mindful Habit Tracker',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFA8A29E),
                          letterSpacing: 0.2,
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  final AnimationController glow;
  final Color primary;
  final Color brand;
  final Color peachLight;

  const _AppIcon({required this.glow, required this.primary, required this.brand, required this.peachLight});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blurred pulsing halo backdrop
          AnimatedBuilder(
            animation: glow,
            builder: (context, _) {
              final t = 0.85 + glow.value * 0.15;
              final opacity = 0.28 + glow.value * 0.12;
              return Transform.scale(
                scale: t,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [primary.withValues(alpha: opacity), brand.withValues(alpha: opacity)],
                    ),
                  ),
                ),
              );
            },
          ),
          // Main squircle icon
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8159), Color(0xFFF26435), Color(0xFFE25528)],
              ),
              boxShadow: [
                BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 16)),
                BoxShadow(color: primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 6)),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.2), Colors.black.withValues(alpha: 0.1)],
                ),
              ),
              child: const Center(
                child: Icon(Icons.check, color: Colors.white, size: 48),
              ),
            ),
          ),
          // Floating "Active" streak badge
          Positioned(
            bottom: 6,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: peachLight.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text(
                    'Active',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: primary,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// A pill-shaped progress track with a shimmering fill, matching the Stitch
/// "loading" footer treatment.
class _LoadingBar extends StatefulWidget {
  final Color primary;
  final Color brand;
  const _LoadingBar({required this.primary, required this.brand});

  @override
  State<_LoadingBar> createState() => _LoadingBarState();
}

class _LoadingBarState extends State<_LoadingBar> with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 144,
        height: 6,
        color: const Color(0xFFE7E5E4),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: 2 / 3,
          child: Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [widget.brand, widget.primary]),
                ),
              ),
              AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) {
                  return Align(
                    alignment: Alignment(-1 + _shimmer.value * 2, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.4,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.65),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
