import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/screen_title.dart';

const _lookbackDays = 30;

DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Analytics screen — numeric trends and per-habit breakdowns, separate
/// from the Streaks screen (which owns the circular streak visual).
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider);
    final now = DateTime.now();

    // Last 7 days completion rate, oldest first.
    final last7 = List.generate(7, (i) => _startOfDay(now.subtract(Duration(days: 6 - i))));
    final dailyRates = last7.map((day) {
      final logs = ref.watch(logsForDateProvider(day));
      if (tasks.isEmpty) return 0.0;
      final done = logs.where((l) => l.status == LogStatus.done).length;
      return (done / tasks.length).clamp(0.0, 1.0);
    }).toList();

    // Last 30 days aggregate stats.
    final last30 = List.generate(_lookbackDays, (i) => _startOfDay(now.subtract(Duration(days: i))));
    final allLogs30 = last30.expand((day) => ref.watch(logsForDateProvider(day))).toList();
    final doneCount = allLogs30.where((l) => l.status == LogStatus.done).length;
    final totalPossible = tasks.length * _lookbackDays;
    final overallRate = totalPossible == 0 ? 0.0 : doneCount / totalPossible;

    final bestStreak = tasks.isEmpty
        ? 0
        : tasks
            .map((t) => ref.watch(taskStreakProvider(t.id)))
            .fold<int>(0, (a, b) => a > b ? a : b);

    // Per-habit completion rate over the lookback window.
    final perHabit = tasks.map((task) {
      final logs = last30
          .map((day) => ref.watch(logsForDateProvider(day)))
          .expand((l) => l)
          .where((l) => l.taskId == task.id)
          .toList();
      final done = logs.where((l) => l.status == LogStatus.done).length;
      final rate = done / _lookbackDays;
      return (task: task, rate: rate.clamp(0.0, 1.0));
    }).toList()
      ..sort((a, b) => b.rate.compareTo(a.rate));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            ScreenTitle(
              icon: Icons.bar_chart_rounded,
              color: const Color(0xFF3A86FF),
              title: 'Analytics',
              subtitle: 'Last $_lookbackDays days',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle,
                    iconColor: Colors.green,
                    label: 'Completion',
                    value: '${(overallRate * 100).toInt()}%',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orange,
                    label: 'Best Streak',
                    value: '$bestStreak days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This week', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    _WeeklyBarChart(days: last7, rates: dailyRates),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('By habit', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (perHabit.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No habits yet'),
                      )
                    else
                      for (int i = 0; i < perHabit.length; i++)
                        Padding(
                          padding: EdgeInsets.only(bottom: i == perHabit.length - 1 ? 0 : 14),
                          child: _HabitRateBar(
                            task: perHabit[i].task,
                            rate: perHabit[i].rate,
                            delay: Duration(milliseconds: 60 * i),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated bar chart — each bar grows from 0 to its completion rate on
/// entrance.
class _WeeklyBarChart extends StatefulWidget {
  final List<DateTime> days;
  final List<double> rates;

  const _WeeklyBarChart({required this.days, required this.rates});

  @override
  State<_WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<_WeeklyBarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    const barHeight = 96.0;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < widget.days.length; i++)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: barHeight,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: track,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      width: 22,
                      height: barHeight * widget.rates[i] * t,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormat('E').format(widget.days[i]).substring(0, 1),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

/// Animated horizontal completion-rate bar for a single habit.
class _HabitRateBar extends StatefulWidget {
  final Task task;
  final double rate;
  final Duration delay;

  const _HabitRateBar({required this.task, required this.rate, required this.delay});

  @override
  State<_HabitRateBar> createState() => _HabitRateBarState();
}

class _HabitRateBarState extends State<_HabitRateBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _value;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _value = Tween<double>(begin: 0, end: widget.rate).animate(
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
    return Row(
      children: [
        Icon(IconHelper.fromName(widget.task.icon), size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(
          width: 92,
          child: Text(
            widget.task.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _value,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _value.value,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        AnimatedBuilder(
          animation: _value,
          builder: (context, _) => Text(
            '${(_value.value * 100).toInt()}%',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}
