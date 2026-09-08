import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../providers/providers.dart';
import '../helpers/icon_helper.dart';
import '../screens/add_edit_task_screen.dart';

/// A single row in the today's checklist — matches the new coral/white design.
class TaskTile extends ConsumerWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TaskTile({
    super.key,
    required this.task,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(
      taskStatusProvider((task.id, DateTime.now())),
    );
    final streak = ref.watch(taskStreakProvider(task.id));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isDone = status == TaskStatus.done;
    final accent = IconHelper.colorFor(task.icon);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon circle
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    IconHelper.fromName(task.icon),
                    size: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 14),

                // Name + notes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.notes != null && task.notes!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Padding(
                          padding: const EdgeInsets.only(left: 26),
                          child: Text(
                            task.notes!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Streak badge
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department, size: 12, color: colorScheme.primary),
                        const SizedBox(width: 2),
                        Text(
                          '$streak',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(width: 2),

                // Overflow menu — the discoverable way to edit or delete a
                // habit (long-press on the row still works too).
                SizedBox(
                  width: 32,
                  height: 32,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert, size: 18, color: colorScheme.onSurfaceVariant),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openEdit(context, task);
                          break;
                        case 'delete':
                          _confirmDelete(context, ref, task);
                          break;
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Edit habit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Theme.of(ctx).colorScheme.error),
                            const SizedBox(width: 10),
                            Text('Delete habit', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),

                // Check mark or empty circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone ? accent.withValues(alpha: 0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDone ? accent : colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: isDone
                      ? Icon(
                          Icons.check,
                          size: 15,
                          color: accent,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit?'),
        content: const Text(
          'This will also remove the history for this task. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
    }
  }
}