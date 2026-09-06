import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/screen_title.dart';
import '../widgets/streak_ring.dart';

const _ringColors = [
  Color(0xFFE85D30),
  Color(0xFF3A86FF),
  Color(0xFF2EC4B6),
  Color(0xFFB388FF),
  Color(0xFFFFB703),
  Color(0xFFEF476F),
];

/// Streaks screen — one animated circular streak ring per habit, replacing
/// the GitHub-style contribution heatmap as the primary progress visual.
class StreaksScreen extends ConsumerWidget {
  const StreaksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(activeTasksProvider);

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
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: tasks.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.85,
                    ),
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      final streak = ref.watch(taskStreakProvider(task.id));
                      final color = _ringColors[index % _ringColors.length];
                      return _StreakCard(
                        task: task,
                        streak: streak,
                        color: color,
                        delay: Duration(milliseconds: 80 * index),
                      );
                    },
                  ),
                ],
              ),
      ),
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
      begin: const Offset(0, 0.15),
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
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StreakRing(
                  streak: widget.streak,
                  color: widget.color,
                  size: 84,
                  delay: widget.delay,
                ),
                const SizedBox(height: 10),
                Icon(
                  IconHelper.fromName(widget.task.icon),
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.task.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
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
