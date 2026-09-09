import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/screen_title.dart';
import '../widgets/streak_ring.dart';

const _coralDeep = Color(0xFFE85D30);
const _charcoal = Color(0xFF1E232A);
const _muted = Color(0xFF8A929A);

const _accentColors = [
  Color(0xFFE85D30),
  Color(0xFF3A86FF),
  Color(0xFF2EC4B6),
  Color(0xFFB388FF),
  Color(0xFFFFB703),
  Color(0xFFEF476F),
];

const _badgeDefs = [
  (days: 7, icon: '🛡️', title: '7-Day', subtitle: 'Warrior', colors: [Color(0xFFFF7954), Color(0xFFFFA386)]),
  (days: 14, icon: '⚡', title: 'Two Weeks', subtitle: 'Iron Will', colors: [Color(0xFF3B82F6), Color(0xFF93C5FD)]),
  (days: 30, icon: '👑', title: '30-Day', subtitle: 'Legend', colors: [Color(0xFFF59E0B), Color(0xFFFCD34D)]),
  (days: 60, icon: '💎', title: '60-Day', subtitle: 'Unstoppable', colors: [Color(0xFF06B6D4), Color(0xFF67E8F9)]),
  (days: 100, icon: '🏆', title: '100-Day', subtitle: 'Centurion', colors: [Color(0xFF8B5CF6), Color(0xFFC4B5FD)]),
  (days: 180, icon: '🌟', title: '180-Day', subtitle: 'Devoted', colors: [Color(0xFF10B981), Color(0xFF6EE7B7)]),
  (days: 365, icon: '🔱', title: '365-Day', subtitle: 'Immortal', colors: [Color(0xFFE85D30), Color(0xFFFFB08A)]),
];

DateTime _startOfDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Longest run of consecutive done-days across a task's entire history
/// (not just the currently-active streak).
int _longestStreakEver(List<TaskLog> logs) {
  final doneDays = logs
      .where((l) => l.status == LogStatus.done)
      .map((l) => _startOfDay(l.date))
      .toSet()
      .toList()
    ..sort();

  int best = 0;
  int current = 0;
  DateTime? prev;
  for (final d in doneDays) {
    if (prev != null && d.difference(prev).inDays == 1) {
      current++;
    } else {
      current = 1;
    }
    best = math.max(best, current);
    prev = d;
  }
  return best;
}

/// Fraction of [task]'s *scheduled* days within [days] that ended up
/// "done" — off-schedule days (e.g. weekends for a Weekdays-only habit)
/// aren't counted against it.
double _consistency(List<TaskLog> logs, Task task, List<DateTime> days) {
  final scheduledDays = days.where(task.isScheduledOn).toList();
  if (scheduledDays.isEmpty) return 0;
  final doneDays = logs
      .where((l) => l.taskId == task.id && l.status == LogStatus.done)
      .map((l) => _startOfDay(l.date))
      .toSet();
  final doneScheduledDays = scheduledDays.where(doneDays.contains).length;
  return (doneScheduledDays / scheduledDays.length).clamp(0.0, 1.0);
}

({String label, Color color}) _tierFor(double rate, int streak) {
  if (streak == 0) return (label: 'Getting Started', color: _muted);
  if (rate >= 0.97) return (label: 'On Fire', color: _coralDeep);
  if (rate >= 0.9) return (label: 'Perfect', color: const Color(0xFF1E88E5));
  if (rate >= 0.7) return (label: 'Steady', color: _muted);
  return (label: 'Rising', color: const Color(0xFFD97706));
}

/// Streaks screen (v3) — a Stitch-matched "Streaks & Milestones" dashboard:
/// a warm gradient hero card for the top habit (7-day flame track + next
/// milestone bar), a Best Streak / Consistency stat pair, a per-habit
/// breakdown list with tier badges, and a horizontally scrolling row of
/// milestone badges that unlock as the streak grows.
class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider);
    final storage = ref.watch(storageProvider);

    if (tasks.isEmpty) {
      return const Scaffold(body: _EmptyState());
    }

    final streaks = {
      for (final t in tasks) t.id: ref.watch(taskStreakProvider(t.id)),
    };
    final spotlightTask = tasks.reduce((a, b) => (streaks[a.id] ?? 0) >= (streaks[b.id] ?? 0) ? a : b);
    final spotlightIndex = tasks.indexOf(spotlightTask);
    final spotlightStreak = streaks[spotlightTask.id] ?? 0;
    final spotlightColor = _accentColors[spotlightIndex % _accentColors.length];
    final spotlightLogs = storage.getLogsForTask(spotlightTask.id);

    final now = _startOfDay(DateTime.now());
    final last7 = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));
    final last30 = List.generate(30, (i) => now.subtract(Duration(days: 29 - i)));
    final allLogs30 = last30.expand((day) => ref.watch(logsForDateProvider(day))).toList();

    final spotlightDone7 = last7.map((d) {
      return spotlightLogs.any((l) => l.status == LogStatus.done && _startOfDay(l.date) == d);
    }).toList();
    final startDate = spotlightStreak > 0 ? now.subtract(Duration(days: spotlightStreak - 1)) : null;

    final bestEver = spotlightLogs.isEmpty ? spotlightStreak : math.max(_longestStreakEver(spotlightLogs), spotlightStreak);
    final overallConsistency = tasks.isEmpty
        ? 0.0
        : tasks.map((t) => _consistency(allLogs30, t, last30)).reduce((a, b) => a + b) / tasks.length;

    final habitRows = tasks.map((t) {
      final streak = streaks[t.id] ?? 0;
      final rate = _consistency(allLogs30, t, last30);
      return (task: t, streak: streak, rate: rate);
    }).toList()
      ..sort((a, b) => b.streak.compareTo(a.streak));

    final unlockedBadges = _badgeDefs.where((b) => bestEver >= b.days).length;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          children: [
            const ScreenTitle(
              icon: Icons.local_fire_department_rounded,
              color: _coralDeep,
              title: 'Streaks & Milestones',
              subtitle: 'The flame is alive — keep feeding it',
            ),
            const SizedBox(height: 18),
            _HeroStreakCard(
              task: spotlightTask,
              streak: spotlightStreak,
              startDate: startDate,
              last7: last7,
              done7: spotlightDone7,
              color: spotlightColor,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Best Streak',
                    emoji: '🏆',
                    value: '$bestEver ${bestEver == 1 ? 'Day' : 'Days'}',
                    caption: bestEver > spotlightStreak ? 'Your all-time record' : 'You\'re on it right now',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Consistency',
                    emoji: '✨',
                    value: '${(overallConsistency * 100).round()}%',
                    caption: '${allLogs30.where((l) => l.status == LogStatus.done).length} checks in 30 days',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Individual Habits',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Sorted by streak',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _coralDeep),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < habitRows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HabitRow(
                  task: habitRows[i].task,
                  streak: habitRows[i].streak,
                  rate: habitRows[i].rate,
                  color: _accentColors[tasks.indexOf(habitRows[i].task) % _accentColors.length],
                  delay: Duration(milliseconds: 50 * i),
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Badges Earned',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$unlockedBadges of ${_badgeDefs.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BadgeCarousel(bestEver: bestEver),
          ],
        ),
      ),
    );
  }
}

/// The hero card: warm gradient card for the top habit with a 7-day flame
/// track (lit only for days that habit was actually completed) and a
/// progress bar toward the next milestone.
class _HeroStreakCard extends StatefulWidget {
  final Task task;
  final int streak;
  final DateTime? startDate;
  final List<DateTime> last7;
  final List<bool> done7;
  final Color color;

  const _HeroStreakCard({
    required this.task,
    required this.streak,
    required this.startDate,
    required this.last7,
    required this.done7,
    required this.color,
  });

  List<bool> get scheduled7 => last7.map(task.isScheduledOn).toList();

  @override
  State<_HeroStreakCard> createState() => _HeroStreakCardState();
}

class _HeroStreakCardState extends State<_HeroStreakCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final milestone = nextMilestoneFor(widget.streak);
    final target = milestone == 0 ? 0.0 : (widget.streak / milestone).clamp(0.0, 1.0);
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progress = Tween<double>(begin: 0, end: target).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestone = nextMilestoneFor(widget.streak);
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = _startOfDay(DateTime.now());
    final scheduled7 = widget.scheduled7;
    final doneCount = widget.done7.where((d) => d).length;
    final scheduledCount = scheduled7.where((s) => s).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4EE), Color(0xFFFFEADB), Color(0xFFFFF0E7)],
        ),
        border: Border.all(color: const Color(0xFFFFE1D4)),
        boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    Text('Active Streak', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _coralDeep)),
                  ],
                ),
              ),
              if (widget.startDate != null)
                Text(
                  'Started ${DateFormat.MMMd().format(widget.startDate!)}',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _muted),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.streak > 0 ? '${widget.streak} Days' : '0 Days',
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 34, fontWeight: FontWeight.w800, color: _charcoal, letterSpacing: -0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.streak > 0 ? 'Unbroken momentum on "${widget.task.name}"!' : 'Complete "${widget.task.name}" today to ignite it',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xB3FCDCCE)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('This week\'s check-ins', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _muted)),
                    Text('$doneCount / $scheduledCount Days', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _coralDeep)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int i = 0; i < 7; i++)
                      _FlameNode(
                        label: labels[i],
                        lit: widget.done7[i],
                        scheduled: scheduled7[i],
                        isToday: widget.last7[i] == today,
                        color: widget.color,
                        delay: Duration(milliseconds: 50 * i),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xB3FCDCCE)))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _progress,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF40464E)),
                              children: [
                                const TextSpan(text: 'Next: '),
                                TextSpan(text: '$milestone days', style: const TextStyle(fontWeight: FontWeight.w700, color: _charcoal)),
                              ],
                            ),
                          ),
                        ),
                        Text('${(_progress.value * 100).round()}%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _coralDeep)),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                    padding: const EdgeInsets.all(1.5),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _progress.value,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: const LinearGradient(colors: [Color(0xFFFF8866), Color(0xFFFF5E36)]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Current: ${widget.streak} days', style: const TextStyle(fontSize: 11, color: _muted)),
                    Text('${(milestone - widget.streak).clamp(0, milestone)} days remaining', style: const TextStyle(fontSize: 11, color: _muted)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlameNode extends StatefulWidget {
  final String label;
  final bool lit;
  final bool scheduled;
  final bool isToday;
  final Color color;
  final Duration delay;

  const _FlameNode({
    required this.label,
    required this.lit,
    required this.scheduled,
    required this.isToday,
    required this.color,
    required this.delay,
  });

  @override
  State<_FlameNode> createState() => _FlameNodeState();
}

class _FlameNodeState extends State<_FlameNode> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
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
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return Column(
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: widget.isToday ? FontWeight.w800 : FontWeight.w500,
            color: widget.isToday ? _coralDeep : _muted,
          ),
        ),
        const SizedBox(height: 6),
        ScaleTransition(
          scale: fade,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.lit
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isToday ? [widget.color, Color.lerp(widget.color, Colors.black, 0.15)!] : [widget.color.withValues(alpha: 0.85), widget.color],
                    )
                  : null,
              color: widget.lit ? null : (widget.scheduled ? const Color(0xFFEFEFF1) : Colors.transparent),
              border: widget.isToday
                  ? Border.all(color: Colors.white, width: 2)
                  : (widget.scheduled ? null : Border.all(color: const Color(0xFFD9DBDE), width: 1)),
              boxShadow: widget.lit && widget.isToday
                  ? [BoxShadow(color: widget.color.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 3))]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              widget.lit ? '🔥' : (widget.scheduled ? '' : '·'),
              style: const TextStyle(fontSize: 12, color: Color(0xFFC2C6CB)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String emoji;
  final String value;
  final String caption;

  const _StatCard({required this.label, required this.emoji, required this.value, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _muted)),
              ),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFFFF4EE), borderRadius: BorderRadius.circular(999)),
                child: Text(emoji, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.w800, color: _charcoal)),
          const SizedBox(height: 2),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: _muted)),
        ],
      ),
    );
  }
}

class _HabitRow extends StatefulWidget {
  final Task task;
  final int streak;
  final double rate;
  final Color color;
  final Duration delay;

  const _HabitRow({required this.task, required this.streak, required this.rate, required this.color, required this.delay});

  @override
  State<_HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends State<_HabitRow> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
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
    final tier = _tierFor(widget.rate, widget.streak);
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(_fade),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Icon(IconHelper.fromName(widget.task.icon), size: 21, color: widget.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _charcoal),
                          ),
                        ),
                        if (widget.task.frequencyLabel != 'Daily') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: _muted.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                            child: Text(widget.task.frequencyLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _muted)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text('${widget.streak} ${widget.streak == 1 ? 'day' : 'days'} streak', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF4E555F))),
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
                      color: tier.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: tier.color.withValues(alpha: 0.35)),
                    ),
                    child: Text(tier.label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: tier.color)),
                  ),
                  const SizedBox(height: 4),
                  Text('${(widget.rate * 100).round()}%', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: _muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeCarousel extends StatelessWidget {
  final int bestEver;

  const _BadgeCarousel({required this.bestEver});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _badgeDefs.length,
        separatorBuilder: (context, i) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final b = _badgeDefs[i];
          final unlocked = bestEver >= b.days;
          return _BadgeCard(
            icon: b.icon,
            title: b.title,
            subtitle: b.subtitle,
            colors: b.colors,
            unlocked: unlocked,
            progressLabel: unlocked ? null : '$bestEver/${b.days} Days',
            delay: Duration(milliseconds: 60 * i),
          );
        },
      ),
    );
  }
}

class _BadgeCard extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final bool unlocked;
  final String? progressLabel;
  final Duration delay;

  const _BadgeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.unlocked,
    required this.progressLabel,
    required this.delay,
  });

  @override
  State<_BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<_BadgeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
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
    return ScaleTransition(
      scale: Tween<double>(begin: 0.85, end: 1).animate(_fade),
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          width: 108,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.unlocked ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.unlocked ? const Color(0xFFFFE7DD) : Theme.of(context).colorScheme.outlineVariant,
              style: widget.unlocked ? BorderStyle.solid : BorderStyle.solid,
            ),
            boxShadow: widget.unlocked ? const [BoxShadow(color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 6))] : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: widget.unlocked ? LinearGradient(colors: widget.colors) : null,
                  color: widget.unlocked ? null : const Color(0xFFF1F1F3),
                ),
                alignment: Alignment.center,
                child: Text(widget.unlocked ? widget.icon : '🔒', style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(height: 8),
              Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _charcoal)),
              Text(widget.subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: _muted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.unlocked ? const Color(0xFFFFF2ED) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.unlocked ? 'Unlocked' : (widget.progressLabel ?? ''),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: widget.unlocked ? _coralDeep : _muted,
                  ),
                ),
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
