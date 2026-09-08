import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/streak_ring.dart' show streakMilestones, nextMilestoneFor;

const _lookbackDays = 30;

// Stitch "Daily Check - Streaks & Milestones" design tokens.
const _coral = Color(0xFFFF7652);
const _coralDeep = Color(0xFFE85D30);
const _charcoal = Color(0xFF1E232A);
const _muted = Color(0xFF8A929A);

const _habitIconBg = [
  Color(0xFFFFF1EB),
  Color(0xFFEEF7FF),
  Color(0xFFF4F9F2),
  Color(0xFFFFF8EE),
];
const _habitEmoji = ['🔥', '💧', '📚', '🏃', '🧘', '💊', '🥗', '😴', '✨'];

DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Analytics screen — ported from the Stitch "Streaks & Milestones" design
/// (that project labels this exact screen as the Analytics tab): a hero
/// streak card with a 7-day check-in track and milestone progress bar, quick
/// stat tiles, a sortable per-habit breakdown, and a badge carousel — all
/// wired to real habit data instead of the mockup's static numbers.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  bool _sortByStreak = true;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(activeTasksProvider);
    final now = DateTime.now();

    if (tasks.isEmpty) {
      return const Scaffold(body: _EmptyState());
    }

    final streaks = {
      for (final t in tasks) t.id: ref.watch(taskStreakProvider(t.id)),
    };
    final heroTask =
        tasks.reduce((a, b) => (streaks[a.id] ?? 0) >= (streaks[b.id] ?? 0) ? a : b);
    final heroStreak = streaks[heroTask.id] ?? 0;
    final milestone = nextMilestoneFor(heroStreak);
    final progress = heroStreak <= 0 ? 0.0 : (heroStreak / milestone).clamp(0.0, 1.0);
    final startDate = now.subtract(Duration(days: heroStreak));

    final last7 = List.generate(7, (i) => _startOfDay(now.subtract(Duration(days: 6 - i))));
    final weekChecks = last7.map((day) {
      final logs = ref.watch(logsForDateProvider(day));
      return logs.any((l) => l.taskId == heroTask.id && l.status == LogStatus.done);
    }).toList();
    final weekDoneCount = weekChecks.where((c) => c).length;

    // Last-30-day aggregate consistency across all habits.
    final last30 = List.generate(_lookbackDays, (i) => _startOfDay(now.subtract(Duration(days: i))));
    final allLogs30 = last30.expand((day) => ref.watch(logsForDateProvider(day))).toList();
    final doneCount = allLogs30.where((l) => l.status == LogStatus.done).length;
    final totalPossible = tasks.length * _lookbackDays;
    final consistency = totalPossible == 0 ? 0.0 : doneCount / totalPossible;

    // Per-habit 30-day completion rate.
    final perHabit = tasks.map((task) {
      final logs = allLogs30.where((l) => l.taskId == task.id).toList();
      final done = logs.where((l) => l.status == LogStatus.done).length;
      final rate = (done / _lookbackDays).clamp(0.0, 1.0);
      return (task: task, streak: streaks[task.id] ?? 0, rate: rate);
    }).toList();
    if (_sortByStreak) {
      perHabit.sort((a, b) => b.streak.compareTo(a.streak));
    } else {
      perHabit.sort((a, b) => a.task.name.compareTo(b.task.name));
    }

    final badgeMilestones = streakMilestones.take(4).toList();
    final unlockedCount = badgeMilestones.where((m) => heroStreak >= m).length;

    return Scaffold(
      backgroundColor: const Color(0xFFECEBED),
      body: SafeArea(
        child: Column(
          children: [
            _AnalyticsNav(
              onMorePressed: () => setState(() => _sortByStreak = !_sortByStreak),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                children: [
                  _HeroStreakCard(
                    heroStreak: heroStreak,
                    startDate: startDate,
                    weekChecks: weekChecks,
                    weekDoneCount: weekDoneCount,
                    milestone: milestone,
                    progress: progress,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          label: 'Best Streak',
                          emoji: '🏆',
                          value: '$heroStreak Days',
                          caption: heroStreak > 0
                              ? 'Since ${DateFormat('MMMM y').format(startDate)}'
                              : 'Start a habit to begin',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          label: 'Consistency',
                          emoji: '✨',
                          value: '${(consistency * 100).round()}%',
                          caption: '$doneCount total checks',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Individual Habits',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _charcoal,
                              ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _sortByStreak = !_sortByStreak),
                          child: Text(
                            _sortByStreak ? 'Sort by streak' : 'Sort by name',
                            style: const TextStyle(
                              color: _coralDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < perHabit.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HabitRow(
                        task: perHabit[i].task,
                        streak: perHabit[i].streak,
                        rate: perHabit[i].rate,
                        emoji: _habitEmoji[i % _habitEmoji.length],
                        bg: _habitIconBg[i % _habitIconBg.length],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Badges Earned',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _charcoal,
                              ),
                        ),
                        Text(
                          '$unlockedCount of ${badgeMilestones.length}',
                          style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 118,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: badgeMilestones.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final m = badgeMilestones[i];
                        return _BadgeCard(
                          milestone: m,
                          heroStreak: heroStreak,
                          index: i,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsNav extends StatelessWidget {
  final VoidCallback onMorePressed;

  const _AnalyticsNav({required this.onMorePressed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4))],
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: _coralDeep, size: 20),
          ),
          const Text(
            'Streaks & Milestones',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 19,
              color: _charcoal,
              letterSpacing: -0.2,
            ),
          ),
          GestureDetector(
            onTap: onMorePressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: const Icon(Icons.sort_rounded, color: Color(0xFF2A2E35), size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero gradient card: current best streak, a 7-day check-in track, and a
/// progress bar toward the next milestone.
class _HeroStreakCard extends StatefulWidget {
  final int heroStreak;
  final DateTime startDate;
  final List<bool> weekChecks;
  final int weekDoneCount;
  final int milestone;
  final double progress;

  const _HeroStreakCard({
    required this.heroStreak,
    required this.startDate,
    required this.weekChecks,
    required this.weekDoneCount,
    required this.milestone,
    required this.progress,
  });

  @override
  State<_HeroStreakCard> createState() => _HeroStreakCardState();
}

class _HeroStreakCardState extends State<_HeroStreakCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF4EE), Color(0xFFFFEADB), Color(0xFFFFF0E7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFFFE1D4)),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 30, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFFD9CA)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🔥', style: TextStyle(fontSize: 13)),
                    SizedBox(width: 6),
                    Text('Active Streak',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _coralDeep)),
                  ],
                ),
              ),
              Text(
                widget.heroStreak > 0 ? 'Started ${DateFormat('MMMM d').format(widget.startDate)}' : 'No streak yet',
                style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedBuilder(
                animation: anim,
                builder: (context, _) => Text(
                  '${(widget.heroStreak * anim.value).round()} Days',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: _charcoal),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.heroStreak > 0 ? 'Unbroken momentum!' : 'Complete a habit to start',
                style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0x70FCDCCE)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("This Week's Check-ins", style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
              Text('${widget.weekDoneCount} / 7 Days',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _coralDeep)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (int i = 0; i < 7; i++)
                Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: i == 6 ? FontWeight.w700 : FontWeight.w500,
                        color: i == 6 ? _coralDeep : _muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedScale(
                      scale: widget.weekChecks[i] ? 1 : 0.9,
                      duration: Duration(milliseconds: 300 + i * 60),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: widget.weekChecks[i]
                              ? LinearGradient(
                                  colors: i == 6
                                      ? [const Color(0xFFFF7652), const Color(0xFFE85324)]
                                      : [const Color(0xFFFF8765), const Color(0xFFFF6740)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: widget.weekChecks[i] ? null : const Color(0xFFF3E9E3),
                          border: i == 6 ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(widget.weekChecks[i] ? '🔥' : '', style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x70FCDCCE)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: Color(0xFF40464E), fontWeight: FontWeight.w500),
                  children: [
                    const TextSpan(text: 'Next: '),
                    TextSpan(
                      text: '${widget.milestone} Days',
                      style: const TextStyle(color: _charcoal, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              AnimatedBuilder(
                animation: anim,
                builder: (context, _) => Text(
                  '${(widget.progress * anim.value * 100).round()}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _coralDeep),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 10,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFFFD9CA)),
            ),
            child: AnimatedBuilder(
              animation: anim,
              builder: (context, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widget.progress * anim.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(colors: [Color(0xFFFF8866), Color(0xFFFF5E36)]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current: ${widget.heroStreak} days', style: const TextStyle(fontSize: 11, color: _muted)),
              Text('${widget.milestone - widget.heroStreak} days remaining', style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String emoji;
  final String value;
  final String caption;

  const _StatTile({required this.label, required this.emoji, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w500)),
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: Color(0xFFFFF4EE), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _charcoal)),
          const SizedBox(height: 2),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: _muted)),
        ],
      ),
    );
  }
}

class _HabitRow extends StatelessWidget {
  final Task task;
  final int streak;
  final double rate;
  final String emoji;
  final Color bg;

  const _HabitRow({
    required this.task,
    required this.streak,
    required this.rate,
    required this.emoji,
    required this.bg,
  });

  ({String label, Color fg, Color bg, Color? border}) get _badge {
    if (rate >= 0.95) {
      return (label: 'Perfect', fg: const Color(0xFF1E88E5), bg: const Color(0xFFF0F7FF), border: const Color(0xFFD0E6FC));
    }
    if (streak > 0 && rate >= 0.8) {
      return (label: 'On Fire', fg: _coralDeep, bg: const Color(0xFFFFF0EA), border: const Color(0xFFFFD5C5));
    }
    if (rate >= 0.5) {
      return (label: 'Steady', fg: _muted, bg: const Color(0xFFF5F5F7), border: null);
    }
    return (label: 'Rising', fg: const Color(0xFFD97706), bg: const Color(0xFFFFF9ED), border: const Color(0xFFFDE68A));
  }

  @override
  Widget build(BuildContext context) {
    final b = _badge;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _charcoal),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Text('$streak days streak', style: const TextStyle(fontSize: 12, color: Color(0xFF4E555F), fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: b.bg,
                  borderRadius: BorderRadius.circular(999),
                  border: b.border != null ? Border.all(color: b.border!) : null,
                ),
                child: Text(b.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: b.fg)),
              ),
              const SizedBox(height: 4),
              Text('${(rate * 100).round()}%', style: const TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

const _badgeLabels = {
  7: (title: '7-Day', subtitle: 'Warrior', colors: [Color(0xFFFF7954), Color(0xFFFFA386)], icon: '🛡️'),
  14: (title: 'Two Weeks', subtitle: 'Iron Will', colors: [Color(0xFF3B82F6), Color(0xFF93C5FD)], icon: '⚡'),
  30: (title: '30-Day', subtitle: 'Legend', colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)], icon: '🌅'),
  60: (title: '60-Day', subtitle: 'Champion', colors: [Color(0xFF10B981), Color(0xFF6EE7B7)], icon: '🌟'),
};

class _BadgeCard extends StatelessWidget {
  final int milestone;
  final int heroStreak;
  final int index;

  const _BadgeCard({required this.milestone, required this.heroStreak, required this.index});

  @override
  Widget build(BuildContext context) {
    final unlocked = heroStreak >= milestone;
    final meta = _badgeLabels[milestone] ?? (title: '$milestone-Day', subtitle: 'Milestone', colors: const [_coral, _coralDeep], icon: '🏅');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 120),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.scale(scale: 0.85 + 0.15 * t, child: Opacity(opacity: t.clamp(0, 1), child: child)),
      child: Container(
        width: 112,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? Colors.white : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: unlocked ? const Color(0xFFFFE7DD) : const Color(0xFFD1D5DB),
            style: unlocked ? BorderStyle.solid : BorderStyle.solid,
          ),
          boxShadow: unlocked ? const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 6))] : null,
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: unlocked
                    ? LinearGradient(colors: meta.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)
                    : null,
                color: unlocked ? null : const Color(0xFFF3F4F6),
              ),
              alignment: Alignment.center,
              child: Text(unlocked ? meta.icon : '🔒', style: TextStyle(fontSize: unlocked ? 18 : 15)),
            ),
            const SizedBox(height: 8),
            Text(
              meta.title,
              maxLines: 1,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: unlocked ? _charcoal : const Color(0xFF4B535D)),
            ),
            Text(meta.subtitle, style: const TextStyle(fontSize: 10, color: _muted)),
            const SizedBox(height: 6),
            if (unlocked)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFFFF2ED), borderRadius: BorderRadius.circular(6)),
                child: const Text('UNLOCKED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _coralDeep, letterSpacing: 0.4)),
              )
            else
              Text('$heroStreak/$milestone Days', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: _muted)),
          ],
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
            const Icon(Icons.insights_rounded, size: 48, color: _muted),
            const SizedBox(height: 12),
            const Text('Add a habit to see your analytics', style: TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }
}
