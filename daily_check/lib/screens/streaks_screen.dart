import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/screen_title.dart';
import '../widgets/streak_ring.dart';

const _accentColors = [
  Color(0xFFE85D30),
  Color(0xFF3A86FF),
  Color(0xFF2EC4B6),
  Color(0xFFB388FF),
  Color(0xFFFFB703),
  Color(0xFFEF476F),
];

const _sparklineDays = 14;

DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Streaks screen — a bold, colorful "how am I doing" dashboard: a hero
/// summary card with animated counters, followed by rich per-habit cards
/// combining a milestone ring with a 14-day activity sparkline. Replaces
/// both the GitHub-style heatmap and the plain streak grid with something
/// more visual and data-driven.
class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider);
    final streaks = {
      for (final t in tasks) t.id: ref.watch(taskStreakProvider(t.id)),
    };
    final totalFlame = streaks.values.fold<int>(0, (a, b) => a + b);
    final onFireCount = streaks.values.where((s) => s > 0).length;
    final longest = streaks.values.isEmpty
        ? 0
        : streaks.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      body: SafeArea(
        child: tasks.isEmpty
            ? const _EmptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                children: [
                  const ScreenTitle(
                    icon: Icons.local_fire_department_rounded,
                    color: Color(0xFFE85D30),
                    title: 'Streaks',
                    subtitle: 'Keep the flame alive on every habit',
                  ),
                  const SizedBox(height: 16),
                  _StreaksHero(
                    totalFlame: totalFlame,
                    onFireCount: onFireCount,
                    totalHabits: tasks.length,
                    longest: longest,
                  ),
                  const SizedBox(height: 20),
                  for (int i = 0; i < tasks.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _StreakCard(
                        task: tasks[i],
                        streak: streaks[tasks[i].id] ?? 0,
                        color: _accentColors[i % _accentColors.length],
                        delay: Duration(milliseconds: 90 * i),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Gradient hero card summarizing all streaks at a glance: total combined
/// streak days, how many habits are "on fire" today, and the longest streak.
class _StreaksHero extends StatefulWidget {
  final int totalFlame;
  final int onFireCount;
  final int totalHabits;
  final int longest;

  const _StreaksHero({
    required this.totalFlame,
    required this.onFireCount,
    required this.totalHabits,
    required this.longest,
  });

  @override
  State<_StreaksHero> createState() => _StreaksHeroState();
}

class _StreaksHeroState extends State<_StreaksHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    const primary = Color(0xFFE85D30);
    const secondary = Color(0xFFFF8A65);
    const glow = Color(0xFFFFC93C);

    return FadeTransition(
      opacity: anim,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [secondary, primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pulse = 1.0 + (0.08 * (1 - (_controller.value - 0.5).abs() * 2));
                    return Transform.scale(scale: _controller.isCompleted ? 1 : pulse, child: child);
                  },
                  child: const Icon(Icons.local_fire_department_rounded, color: glow, size: 30),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Momentum',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                _AnimatedCounter(
                  value: widget.longest,
                  anim: anim,
                  suffix: 'd best',
                  textStyle: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Total streak days',
                    anim: anim,
                    value: widget.totalFlame,
                  ),
                ),
                Container(width: 1, height: 36, color: Colors.white24),
                Expanded(
                  child: _HeroStat(
                    label: 'Habits on fire',
                    anim: anim,
                    value: widget.onFireCount,
                    suffix: '/${widget.totalHabits}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final Animation<double> anim;
  final int value;
  final String? suffix;

  const _HeroStat({required this.label, required this.anim, required this.value, this.suffix});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AnimatedCounter(
          value: value,
          anim: anim,
          suffix: suffix ?? '',
          textStyle: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _AnimatedCounter extends StatelessWidget {
  final int value;
  final Animation<double> anim;
  final String suffix;
  final TextStyle textStyle;

  const _AnimatedCounter({
    required this.value,
    required this.anim,
    required this.suffix,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final shown = (value * anim.value).round();
        return Text('$shown$suffix', style: textStyle);
      },
    );
  }
}

class _StreakCard extends StatefulWidget {
  final Task task;
  final int streak;
  final Color color;
  final Duration delay;

  const _StreakCard({
    required this.task,
    required this.streak,
    required this.color,
    required this.delay,
  });

  @override
  State<_StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<_StreakCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0.06, 0.1),
      end: Offset.zero,
    ).animate(_fade);
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
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: widget.color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: widget.streak > 0 ? 0.18 : 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StreakRing(streak: widget.streak, color: widget.color, size: 68, delay: widget.delay),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: widget.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Icon(IconHelper.fromName(widget.task.icon), size: 15, color: widget.color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.task.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.streak > 0
                              ? '${nextMilestoneFor(widget.streak) - widget.streak} days to ${nextMilestoneFor(widget.streak)}-day milestone'
                              : 'Complete it today to start a streak',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Sparkline(taskId: widget.task.id, color: widget.color, delay: widget.delay),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tiny animated bar chart of the last 14 days for one habit — done days
/// filled in the habit's accent color, missed/pending days shown as a
/// faint track, today's bar outlined.
class _Sparkline extends ConsumerStatefulWidget {
  final String taskId;
  final Color color;
  final Duration delay;

  const _Sparkline({required this.taskId, required this.color, required this.delay});

  @override
  ConsumerState<_Sparkline> createState() => _SparklineState();
}

class _SparklineState extends ConsumerState<_Sparkline> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
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
    final today = _startOfDay(DateTime.now());
    final days = List.generate(_sparklineDays, (i) => today.subtract(Duration(days: _sparklineDays - 1 - i)));
    final done = days.map((day) {
      final logs = ref.watch(logsForDateProvider(day));
      return logs.any((l) => l.taskId == widget.taskId && l.status == LogStatus.done);
    }).toList();

    final track = Theme.of(context).colorScheme.surfaceContainerHighest;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return SizedBox(
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int i = 0; i < days.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: done[i] ? 32 * t : 10,
                      decoration: BoxDecoration(
                        color: done[i] ? widget.color.withValues(alpha: 0.85) : track,
                        borderRadius: BorderRadius.circular(4),
                        border: days[i] == today
                            ? Border.all(color: widget.color, width: 1.4)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
            Icon(
              Icons.local_fire_department,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('Add a habit to start building a streak'),
          ],
        ),
      ),
    );
  }
}
