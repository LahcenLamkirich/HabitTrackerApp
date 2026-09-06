import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/task_tile.dart';
import 'add_edit_task_screen.dart';

/// The home screen — today's checklist.
///
/// Shows all active tasks for today, with their current status. Tapping a
/// task toggles its done state. Long-pressing opens the edit screen.
///
/// Matches the Stitch "Daily Check - Today's Habits (Home)" design.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider);
    final statuses = ref.watch(todayTaskStatusesProvider);
    final settings = ref.watch(settingsProvider);

    final doneCount = statuses.values.where((s) => s == TaskStatus.done).length;
    final total = tasks.length;
    final progress = total == 0 ? 0.0 : doneCount / total;

    // Calculate best streak from all tasks
    int bestStreak = 0;
    for (final task in tasks) {
      final streak = ref.read(taskStreakProvider(task.id));
      if (streak > bestStreak) bestStreak = streak;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F7F4),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF9F7F4),
            surfaceTintColor: Colors.transparent,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF8A65), Color(0xFFE85D30)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.task_alt_rounded, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Daily Check',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: Color(0xFF1F2429),
                  ),
                ),
              ],
            ),
            actions: [
              if (settings.notificationsEnabled)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF1F2429),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.notifications_off_outlined,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: _Header(
              date: DateTime.now(),
              doneCount: doneCount,
              total: total,
              progress: progress,
              bestStreak: bestStreak,
            ),
          ),
          if (tasks.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverList.builder(
              itemCount: tasks.length,
              itemBuilder: (context, i) {
                final task = tasks[i];
                final status = statuses[task.id] ?? TaskStatus.pending;
                return TaskTile(
                  task: task,
                  onTap: () => _onToggle(context, ref, task, status),
                  onLongPress: () => _openEdit(context, task),
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  void _onToggle(
    BuildContext context,
    WidgetRef ref,
    Task task,
    TaskStatus status,
  ) {
    final notifier = ref.read(taskNotifierProvider.notifier);
    if (status == TaskStatus.done || status == TaskStatus.skipped) {
      notifier.undoToday(task.id);
    } else {
      notifier.markDone(task.id);
    }
  }

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddEditTaskScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  void _openEdit(BuildContext context, Task task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditTaskScreen(task: task),
        fullscreenDialog: true,
      ),
    );
  }
}

/// The daily progress card with ring indicator and stats.
///
/// Matches Stitch design: pale peach gradient, two-column layout, coral ring.
class _Header extends StatelessWidget {
  final DateTime date;
  final int doneCount;
  final int total;
  final double progress;
  final int bestStreak;

  const _Header({
    required this.date,
    required this.doneCount,
    required this.total,
    required this.progress,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat("EEEE, MMMM d").format(date);

    // Stitch tokens
    const primary = Color(0xFFE85D30);
    const secondary = Color(0xFFFF8A65);
    const tertiary = Color(0xFFFFEDE6);
    const textHigh = Color(0xFF1F2429);
    const textMedium = Color(0xFF4B5563);
    const trackBg = Color(0xFFF2EBE5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date label
          Text(
            dateLabel,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: textMedium,
            ),
          ),
          const SizedBox(height: 16),

          // Progress card — pale peach gradient
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [tertiary, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A1F2429),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Left: progress stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Progress',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textHigh,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$doneCount of $total completed',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textMedium,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Streak with flame icon
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 16,
                            color: primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Best streak: $bestStreak days',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: textMedium,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Right: circular ring
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CustomPaint(
                    painter: _RingPainter(
                      progress: progress,
                      backgroundColor: trackBg,
                      progressColor: primary,
                      strokeWidth: 7,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check,
                        size: 28,
                        color: primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular ring painter with rounded stroke caps.
class _RingPainter extends CustomPainter {
  final double progress;
  final Color backgroundColor;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
    this.strokeWidth = 7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    final progressAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    if (progressAngle > 0.0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progressAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) {
    return old.progress != progress ||
        old.backgroundColor != backgroundColor ||
        old.progressColor != progressColor;
  }
}

/// Empty state when no tasks exist.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFE85D30);
    const textHigh = Color(0xFF1F2429);
    const textMedium = Color(0xFF4B5563);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDE6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.task_alt,
                size: 36,
                color: primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No habits yet',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: textHigh,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first daily habit\nand start building streaks!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textMedium,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
