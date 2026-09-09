import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/screen_title.dart';

const _lookbackDays = 30;
const _trendDays = 14;

const _done = Color(0xFF2EC4B6);
const _missed = Color(0xFFEF476F);
const _skipped = Color(0xFFB8BCC4);
const _leaderColors = [
  Color(0xFFFFD166),
  Color(0xFFC0C6CF),
  Color(0xFFE0A96D),
];
const _rankAccents = [
  Color(0xFFE85D30),
  Color(0xFF3A86FF),
  Color(0xFF2EC4B6),
  Color(0xFFB388FF),
  Color(0xFFFFB703),
];

DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Analytics screen (v2) — an original "Insights" dashboard: a custom-painted
/// donut breaking down done/missed/skipped days, an animated 14-day
/// completion-rate trend line, and a medal-style leaderboard ranking habits
/// by streak. Deliberately not the Stitch mock-up — a punchier multi-color
/// palette instead of a single coral theme.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider);
    final now = DateTime.now();

    if (tasks.isEmpty) {
      return const Scaffold(body: _EmptyState());
    }

    final last30 = List.generate(_lookbackDays, (i) => _startOfDay(now.subtract(Duration(days: i))));
    final allLogs30 = last30.expand((day) => ref.watch(logsForDateProvider(day))).toList();
    final doneCount = allLogs30.where((l) => l.status == LogStatus.done).length;
    final missedCount = allLogs30.where((l) => l.status == LogStatus.missed).length;
    final skippedCount = allLogs30.where((l) => l.status == LogStatus.skipped).length;
    final totalPossible = tasks.length * _lookbackDays;
    final untouched = (totalPossible - doneCount - missedCount - skippedCount).clamp(0, totalPossible);
    final overallRate = totalPossible == 0 ? 0.0 : doneCount / totalPossible;

    final last14 = List.generate(_trendDays, (i) => _startOfDay(now.subtract(Duration(days: _trendDays - 1 - i))));
    final trend = last14.map((day) {
      final logs = ref.watch(logsForDateProvider(day));
      if (tasks.isEmpty) return 0.0;
      final done = logs.where((l) => l.status == LogStatus.done).length;
      return (done / tasks.length).clamp(0.0, 1.0);
    }).toList();

    final leaderboard = tasks.map((t) {
      final streak = ref.watch(taskStreakProvider(t.id));
      final logs = allLogs30.where((l) => l.taskId == t.id).toList();
      final rate = (logs.where((l) => l.status == LogStatus.done).length / _lookbackDays).clamp(0.0, 1.0);
      return (task: t, streak: streak, rate: rate);
    }).toList()
      ..sort((a, b) => b.streak.compareTo(a.streak));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          children: [
            const ScreenTitle(
              icon: Icons.insights_rounded,
              color: Color(0xFF3A86FF),
              title: 'Insights',
              subtitle: 'How your last 30 days really went',
            ),
            const SizedBox(height: 18),
            _DonutBreakdownCard(
              done: doneCount,
              missed: missedCount,
              skipped: skippedCount,
              untouched: untouched,
              overallRate: overallRate,
            ),
            const SizedBox(height: 16),
            _TrendChartCard(days: last14, rates: trend),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                'Leaderboard',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < leaderboard.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LeaderRow(
                  rank: i,
                  task: leaderboard[i].task,
                  streak: leaderboard[i].streak,
                  rate: leaderboard[i].rate,
                  accent: _rankAccents[i % _rankAccents.length],
                  delay: Duration(milliseconds: 60 * i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A ring-shaped breakdown of done/missed/skipped/untouched days across all
/// habits over the last 30 days, drawn as a multi-segment animated arc with
/// the overall completion rate in the center.
class _DonutBreakdownCard extends StatefulWidget {
  final int done;
  final int missed;
  final int skipped;
  final int untouched;
  final double overallRate;

  const _DonutBreakdownCard({
    required this.done,
    required this.missed,
    required this.skipped,
    required this.untouched,
    required this.overallRate,
  });

  @override
  State<_DonutBreakdownCard> createState() => _DonutBreakdownCardState();
}

class _DonutBreakdownCardState extends State<_DonutBreakdownCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.done + widget.missed + widget.skipped + widget.untouched;
    final anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DonutPainter(
                    segments: total == 0
                        ? [(_skipped, 1.0)]
                        : [
                            (_done, widget.done / total),
                            (_missed, widget.missed / total),
                            (_skipped, widget.skipped / total),
                            (Theme.of(context).colorScheme.surfaceContainerHighest, widget.untouched / total),
                          ],
                    progress: anim.value,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(widget.overallRate * anim.value * 100).round()}%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text('done', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Last 30 days', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                _LegendDot(color: _done, label: 'Done', count: widget.done),
                const SizedBox(height: 6),
                _LegendDot(color: _missed, label: 'Missed', count: widget.missed),
                const SizedBox(height: 6),
                _LegendDot(color: _skipped, label: 'Skipped', count: widget.skipped),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendDot({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Text('$count', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(Color, double)> segments;
  final double progress;

  _DonutPainter({required this.segments, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 9;
    const strokeWidth = 14.0;
    double start = -math.pi / 2;

    for (final (color, fraction) in segments) {
      if (fraction <= 0) continue;
      final sweep = 2 * math.pi * fraction * progress;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, paint);
      start += 2 * math.pi * fraction;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments || oldDelegate.progress != progress;
}

/// A smooth animated line chart of the daily completion rate over the last
/// 14 days, with a gradient fill under the curve.
class _TrendChartCard extends StatefulWidget {
  final List<DateTime> days;
  final List<double> rates;

  const _TrendChartCard({required this.days, required this.rates});

  @override
  State<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends State<_TrendChartCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    const accent = Color(0xFFB388FF);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 22, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('14-day trend', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 100),
                  painter: _TrendPainter(
                    rates: widget.rates,
                    progress: anim.value,
                    lineColor: accent,
                    trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.days.length} days ago', style: Theme.of(context).textTheme.labelSmall),
              Text('Today', style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> rates;
  final double progress;
  final Color lineColor;
  final Color trackColor;

  _TrendPainter({required this.rates, required this.progress, required this.lineColor, required this.trackColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (rates.isEmpty) return;
    final n = rates.length;
    final stepX = n > 1 ? size.width / (n - 1) : size.width;

    Offset pointAt(int i) => Offset(stepX * i, size.height - (rates[i] * size.height));

    // Baseline grid.
    final gridPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = size.height - (size.height * f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final visibleCount = (n * progress).ceil().clamp(1, n);
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (int i = 1; i < visibleCount; i++) {
      final p0 = pointAt(i - 1);
      final p1 = pointAt(i);
      final mid = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(p0.dx, p0.dy, mid.dx, mid.dy);
      if (i == visibleCount - 1) path.lineTo(p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(pointAt(visibleCount - 1).dx, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.02)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (int i = 0; i < visibleCount; i++) {
      canvas.drawCircle(pointAt(i), i == visibleCount - 1 ? 4.5 : 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.rates != rates || oldDelegate.progress != progress;
}

/// A leaderboard row ranking a habit by current streak — top 3 get a medal
/// badge, the rest a plain rank number, plus a mini completion-rate bar.
class _LeaderRow extends StatefulWidget {
  final int rank;
  final Task task;
  final int streak;
  final double rate;
  final Color accent;
  final Duration delay;

  const _LeaderRow({
    required this.rank,
    required this.task,
    required this.streak,
    required this.rate,
    required this.accent,
    required this.delay,
  });

  @override
  State<_LeaderRow> createState() => _LeaderRowState();
}

class _LeaderRowState extends State<_LeaderRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _rate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _rate = Tween<double>(begin: 0, end: widget.rate).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
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
    final isMedal = widget.rank < 3;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(-0.05, 0), end: Offset.zero).animate(_fade),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMedal ? _leaderColors[widget.rank] : widget.accent.withValues(alpha: 0.12),
                ),
                child: isMedal
                    ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16)
                    : Text('${widget.rank + 1}', style: TextStyle(color: widget.accent, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(IconHelper.fromName(widget.task.icon), size: 17, color: widget.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: _rate,
                        builder: (context, _) => LinearProgressIndicator(
                          value: _rate.value,
                          minHeight: 5,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(widget.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFE85D30)),
                      const SizedBox(width: 2),
                      Text('${widget.streak}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Text('${(widget.rate * 100).round()}%', style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Add a habit to see your insights'),
          ],
        ),
      ),
    );
  }
}
