import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Milestones a streak ring animates towards, in ascending order.
const List<int> streakMilestones = [7, 14, 30, 60, 100, 180, 365];

/// The next milestone strictly above [streak] (or the last milestone if
/// [streak] has already passed all of them).
int nextMilestoneFor(int streak) {
  for (final m in streakMilestones) {
    if (streak < m) return m;
  }
  return streakMilestones.last;
}

/// An animated circular progress ring showing a habit's current streak
/// against its next milestone (7/14/30/60/100/180/365 days) — fills in with
/// a spring-like ease when it first appears, replacing the GitHub-style
/// heatmap as the primary "how am I doing" visual.
class StreakRing extends StatefulWidget {
  final int streak;
  final Color color;
  final double size;
  final Duration delay;

  const StreakRing({
    super.key,
    required this.streak,
    required this.color,
    this.size = 96,
    this.delay = Duration.zero,
  });

  @override
  State<StreakRing> createState() => _StreakRingState();
}

class _StreakRingState extends State<StreakRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    final target = widget.streak <= 0
        ? 0.0
        : widget.streak / nextMilestoneFor(widget.streak);
    _progress = Tween<double>(begin: 0, end: target.clamp(0, 1)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    final milestone = nextMilestoneFor(widget.streak);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CustomPaint(
            painter: _RingPainter(
              progress: _progress.value,
              trackColor: track,
              progressColor: widget.color,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: widget.streak > 0
                        ? widget.color
                        : Theme.of(context).colorScheme.outline,
                    size: widget.size * 0.22,
                  ),
                  Text(
                    '${widget.streak}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    '/ $milestone',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - 10) / 2;
    const strokeWidth = 9.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..shader = SweepGradient(
        colors: [progressColor.withValues(alpha: 0.5), progressColor],
        startAngle: 0,
        endAngle: 2 * math.pi * progress,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
