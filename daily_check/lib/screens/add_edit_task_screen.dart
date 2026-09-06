import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/responsive_center.dart';

/// Add or edit a [Task].
///
/// When [task] is null, the screen creates a new task. Otherwise it
/// pre-fills the form with the existing values and updates on save.
class AddEditTaskScreen extends ConsumerStatefulWidget {
  final Task? task;

  const AddEditTaskScreen({super.key, this.task});

  @override
  ConsumerState<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

/// Accent color per icon name, so the live preview and selector chips feel
/// distinct per habit rather than all sharing one primary tint.
const Map<String?, Color> _iconColors = {
  null: Color(0xFFE85D30),
  'supplements': Color(0xFF3A86FF),
  'water': Color(0xFF00B4D8),
  'fitness': Color(0xFFEF476F),
  'medication': Color(0xFFB388FF),
  'food': Color(0xFFFFB703),
  'sleep': Color(0xFF6C63FF),
  'reading': Color(0xFF2EC4B6),
  'workout': Color(0xFFFF6B6B),
  'meditation': Color(0xFF52B788),
};

Color _colorForIcon(String? name) => _iconColors[name] ?? _iconColors[null]!;

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late String? _icon;
  late TimeOfDay? _reminderTime;
  late bool _isActive;
  late String _frequency;
  late final AnimationController _entrance;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _name = TextEditingController(text: t?.name ?? '');
    _notes = TextEditingController(text: t?.notes ?? '');
    _icon = t?.icon;
    _reminderTime = t?.reminderTime;
    _isActive = t?.isActive ?? true;
    _frequency = 'Daily'; // Default frequency
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }

    final notifier = ref.read(taskNotifierProvider.notifier);
    if (_isEditing) {
      final updated = widget.task!.copyWith(
        name: name,
        icon: _icon,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        reminderTime: _reminderTime,
        isActive: _isActive,
      );
      await notifier.updateTask(updated);
    } else {
      await notifier.addTask(
        name: name,
        icon: _icon,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        reminderTime: _reminderTime,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (widget.task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
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
    if (confirmed == true && mounted) {
      await ref.read(taskNotifierProvider.notifier).deleteTask(widget.task!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Widget _staggered(int index, Widget child) {
    final start = (0.1 * index).clamp(0.0, 0.5);
    final anim = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
            .animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = _colorForIcon(_icon);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isEditing ? Icons.edit_rounded : Icons.add_rounded,
                color: Colors.white,
                size: 15,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _isEditing ? 'Edit Habit' : 'New Habit',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          if (_isEditing)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'delete') _delete();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                      const SizedBox(width: 8),
                      const Text('Delete habit'),
                    ],
                  ),
                ),
              ],
            ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          bottom: false,
          child: ResponsiveCenter(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            children: [
              // Live preview
              _staggered(0, _HabitPreview(
                name: _name.text,
                icon: _icon,
                color: accent,
              )),
              const SizedBox(height: 24),

              // Habit name
              _staggered(1, Text(
                'Habit Name',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              )),
              const SizedBox(height: 8),
              _staggered(1, Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _name,
                  autofocus: !_isEditing,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Morning Meditation',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              )),
              const SizedBox(height: 24),

              // Choose Icon
              _staggered(2, Text(
                'Choose Icon',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              )),
              const SizedBox(height: 12),
              _staggered(2, Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _IconSelector(
                    icon: IconHelper.fromName(null),
                    label: 'Default',
                    color: _colorForIcon(null),
                    selected: _icon == null,
                    onTap: () => setState(() => _icon = null),
                  ),
                  for (final name in IconHelper.allNames)
                    _IconSelector(
                      icon: IconHelper.fromName(name),
                      label: name,
                      color: _colorForIcon(name),
                      selected: _icon == name,
                      onTap: () => setState(() => _icon = name),
                    ),
                ],
              )),
              const SizedBox(height: 24),

              // Frequency
              _staggered(3, Text(
                'Frequency',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              )),
              const SizedBox(height: 8),
              _staggered(3, Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FrequencyChip(
                    label: 'Daily',
                    color: accent,
                    selected: _frequency == 'Daily',
                    onSelect: () => setState(() => _frequency = 'Daily'),
                  ),
                  _FrequencyChip(
                    label: 'Weekdays',
                    color: accent,
                    selected: _frequency == 'Weekdays',
                    onSelect: () => setState(() => _frequency = 'Weekdays'),
                  ),
                  _FrequencyChip(
                    label: 'Weekends',
                    color: accent,
                    selected: _frequency == 'Weekends',
                    onSelect: () => setState(() => _frequency = 'Weekends'),
                  ),
                  _FrequencyChip(
                    label: 'Custom',
                    color: accent,
                    selected: _frequency == 'Custom',
                    onSelect: () => setState(() => _frequency = 'Custom'),
                  ),
                ],
              )),
              const SizedBox(height: 24),

              // Reminder time
              _staggered(4, _ReminderTimeField(
                time: _reminderTime,
                color: accent,
                onTap: _pickTime,
                onClear: () => setState(() => _reminderTime = null),
              )),
              const SizedBox(height: 24),

              // Active toggle
              _staggered(4, _ActiveToggle(
                isActive: _isActive,
                color: accent,
                onChanged: (value) => setState(() => _isActive = value),
              )),
              // Bottom padding so the last field isn't hidden behind the
              // sticky footer button when scrolled to the end.
              const SizedBox(height: 24),
            ],
          ),
          ),
        ),
      ),
      // Sticky footer: stays pinned to the bottom of the screen and does
      // NOT scroll with the ListView content above it.
      bottomNavigationBar: SafeArea(
        top: false,
        child: ResponsiveCenter(
          shrinkWrapHeight: true,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.75)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_isEditing ? Icons.check_rounded : Icons.add_rounded),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'Save Changes' : 'Add Habit',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live preview card at the top of the form — a big animated icon avatar
/// with a color that morphs to match the chosen icon, and the habit name
/// echoed back so the user sees what they're building as they build it.
class _HabitPreview extends StatelessWidget {
  final String name;
  final String? icon;
  final Color color;

  const _HabitPreview({required this.name, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.85), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.25),
                border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
              ),
              child: Icon(IconHelper.fromName(icon), color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              name.trim().isEmpty ? 'Your new habit' : name.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconSelector extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _IconSelector({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: selected ? 1 : 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelect;

  const _FrequencyChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onSelect,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? color : colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _ReminderTimeField extends StatelessWidget {
  final TimeOfDay? time;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _ReminderTimeField({
    required this.time,
    required this.color,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.notifications_rounded, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                time == null
                    ? 'Reminder time'
                    : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: time == null ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            ),
            if (time != null)
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close, size: 18, color: colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActiveToggle extends StatelessWidget {
  final bool isActive;
  final Color color;
  final ValueChanged<bool> onChanged;

  const _ActiveToggle({
    required this.isActive,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.check_circle_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Active',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: isActive,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }
}