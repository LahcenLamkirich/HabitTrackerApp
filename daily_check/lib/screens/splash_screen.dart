import 'package:flutter/material.dart';

import 'app_shell.dart';
import '../widgets/responsive_center.dart';

/// The splash / onboarding screen.
///
/// Warm cream canvas, soft card stack illustration, "Daily Check" title in
/// Outfit, and a burnt-coral pill "Get Started" button — matches the Stitch
/// "Mindful Habit Track" design system.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigating = false;

  void _goToHome() {
    if (_navigating) return;
    _navigating = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mindful Habit Track tokens
    const canvas = Color(0xFFF9F7F4);
    const primary = Color(0xFFE85D30);
    const secondary = Color(0xFFFF8A65);
    const tertiary = Color(0xFFFFEDE6);
    const textHigh = Color(0xFF1F2429);
    const textMedium = Color(0xFF4B5563);

    return Scaffold(
      backgroundColor: canvas,
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 480,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Centered illustration: stack of cards on a coral disc
              const Center(
                child: _Illustration(size: 220),
              ),

              const SizedBox(height: 36),

              // App name — Outfit headline
              const Text(
                'Daily Check',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: textHigh,
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              // Tagline — Manrope body
              const Text(
                'Small daily checks,\nBig lifelong progress',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: textMedium,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 3),

              // Get Started button — coral pill with shadow
              Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9999),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _goToHome,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

/// Center illustration: pale peach disc with white card and big coral check,
/// with a small leaf accent — matches Stitch splash.

class _Illustration extends StatelessWidget {
  final double size;
  const _Illustration({required this.size});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE85D30);
    const tertiary = Color(0xFFFFEDE6);
    const secondary = Color(0xFFFF8A65);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pale peach disc backdrop
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(
              color: tertiary,
              shape: BoxShape.circle,
            ),
          ),

          // Back card (peach)
          Positioned(
            top: size * 0.22,
            left: size * 0.32,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                width: size * 0.45,
                height: size * 0.55,
                decoration: BoxDecoration(
                  color: secondary.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // Front card with check — pure white
          Positioned(
            top: size * 0.18,
            left: size * 0.22,
            child: Container(
              width: size * 0.50,
              height: size * 0.62,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F2429).withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Big coral check
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),

                    // Three task lines
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TaskLine(filled: true, widthFraction: 0.85),
                        const SizedBox(height: 6),
                        _TaskLine(filled: false, widthFraction: 0.65),
                        const SizedBox(height: 6),
                        _TaskLine(filled: false, widthFraction: 0.45),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Small leaf accent
          Positioned(
            bottom: size * 0.20,
            left: size * 0.14,
            child: Transform.rotate(
              angle: -0.4,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF6FCF97),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskLine extends StatelessWidget {
  final bool filled;
  final double widthFraction;
  const _TaskLine({required this.filled, required this.widthFraction});

  @override
  Widget build(BuildContext context) {
    const double maxLineWidth = 70.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFFE85D30)
                : const Color(0xFFE5E0D8),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          width: maxLineWidth * widthFraction,
          height: 4,
          decoration: BoxDecoration(
            color: filled
                ? const Color(0xFFE85D30)
                : const Color(0xFFE5E0D8),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}
