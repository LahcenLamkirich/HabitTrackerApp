import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../helpers/icon_helper.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../widgets/responsive_center.dart';
import '../widgets/screen_title.dart';
import 'reminder_step_screen.dart';

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

Color _colorForIcon(String? name) => IconHelper.colorFor(name);

class _AddEditTaskScreenState extends ConsumerState<AddEditTaskScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late String? _icon;
  late TimeOfDay? _reminderTime;
  late bool _isActive;
  late String _frequency;
  late Set<int> _customDays;
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
    _frequency = t?.frequencyLabel ?? 'Daily';
    _customDays = (t != null ? t.activeWeekdays.toSet() : <int>{});
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

  /// Turns the Frequency selection into the [Task.activeWeekdays] list the
  /// rest of the app (Today's checklist, streaks, consistency) actually
  /// schedules against. Returns null if 'Custom' is selected but no day
  /// has been picked yet — the rule needs at least one day to mean anything.
  List<int>? _resolveActiveWeekdays() {
    switch (_frequency) {
      case 'Weekdays':
        return const [1, 2, 3, 4, 5];
      case 'Weekends':
        return const [6, 7];
      case 'Custom':
        return _customDays.isEmpty ? null : (_customDays.toList()..sort());
      case 'Daily':
      default:
        return kAllWeekdays;
    }
  }

  /// Saves changes to an existing habit. Editing keeps the reminder field
  /// inline (no wizard) since the value is already known.
  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    final activeWeekdays = _resolveActiveWeekdays();
    if (activeWeekdays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one day for a custom schedule')),
      );
      return;
    }

    final updated = widget.task!.copyWith(
      name: name,
      icon: _icon,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      reminderTime: _reminderTime,
      isActive: _isActive,
      activeWeekdays: activeWeekdays,
    );
    await ref.read(taskNotifierProvider.notifier).updateTask(updated);

    if (mounted) Navigator.of(context).pop();
  }

  /// For new habits: hands off to the reminder step (a separate, skippable
  /// screen) instead of saving immediately, so setting a reminder reads as
  /// an explicit — but optional — step rather than a buried form field.
  Future<void> _continueToReminderStep() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    final activeWeekdays = _resolveActiveWeekdays();
    if (activeWeekdays == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one day for a custom schedule')),
      );
      return;
    }

    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => ReminderStepScreen(
          habitName: name,
          accent: _colorForIcon(_icon),
          initialTime: _reminderTime,
        ),
      ),
    );
    if (result == null || !mounted) return; // backed out — stay on the form

    final reminder = result is TimeOfDay ? result : null;
    await ref.read(taskNotifierProvider.notifier).addTask(
          name: name,
          icon: _icon,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          reminderTime: reminder,
          activeWeekdays: activeWeekdays,
        );

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
              if (!_isEditing) ...[
                _staggered(0, Row(
                  children: [
                    Container(width: 28, height: 5, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 6),
                    Container(width: 28, height: 5, decoration: BoxDecoration(color: accent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4))),
                  ],
                )),
                const SizedBox(height: 8),
                _staggered(0, Text(
                  'STEP 1 OF 2',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                )),
                const SizedBox(height: 12),
              ],
              // Title
              _staggered(0, ScreenTitle(
                icon: _isEditing ? Icons.edit_rounded : Icons.add_task_rounded,
                color: accent,
                title: _isEditing ? 'Edit Habit' : 'New Habit',
                subtitle: _isEditing
                    ? 'Fine-tune how this habit works'
                    : 'Set it up once, build it daily',
              )),
              const SizedBox(height: 16),

              // Live preview
              _staggered(0, _HabitPreview(
                name: _name.text,
                icon: _icon,
                color: accent,
              )),
              const SizedBox(height: 20),

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
              if (_frequency == 'Custom') ...[
                const SizedBox(height: 12),
                _staggered(3, _CustomDayPicker(
                  selected: _customDays,
                  color: accent,
                  onToggle: (day) => setState(() {
                    if (_customDays.contains(day)) {
                      _customDays.remove(day);
                    } else {
                      _customDays.add(day);
                    }
                  }),
                )),
              ],
              const SizedBox(height: 24),

              // Reminder time — inline only while editing; new habits set
              // this in the dedicated (skippable) reminder step instead.
              if (_isEditing) ...[
                _staggered(4, _ReminderTimeField(
                  time: _reminderTime,
                  color: accent,
                  onTap: _pickTime,
                  onClear: () => setState(() => _reminderTime = null),
                )),
                const SizedBox(height: 24),
              ],

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
                onPressed: _isEditing ? _save : _continueToReminderStep,
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
                    Text(
                      _isEditing ? 'Save Changes' : 'Continue',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_isEditing ? Icons.check_rounded : Icons.arrow_forward_rounded),
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

/// A live "how this'll look in your Today list" preview — styled exactly
/// like the real [TaskTile] row, with a soft pulsing glow behind the icon
/// so it doesn't sit static while the rest of the form comes alive.
class _HabitPreview extends StatefulWidget {
  final String name;
  final String? icon;
  final Color color;

  const _HabitPreview({required this.name, required this.icon, required this.color});

  @override
  State<_HabitPreview> createState() => _HabitPreviewState();
}

class _HabitPreviewState extends State<_HabitPreview> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = widget.name.trim().isEmpty ? 'Your new habit' : widget.name.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              Icon(Icons.visibility_outlined, size: 13, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 5),
              Text(
                'HOW IT LOOKS IN YOUR LIST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(color: widget.color.withValues(alpha: 0.1), blurRadius: 14, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 44 + _pulse.value * 10,
                          height: 44 + _pulse.value * 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.color.withValues(alpha: 0.12 * (1 - _pulse.value)),
                          ),
                        ),
                        child!,
                      ],
                    );
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(IconHelper.fromName(widget.icon), size: 19, color: widget.color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 11, color: widget.color),
                    const SizedBox(width: 3),
                    Text('New', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.color)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
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

/// Seven toggleable day circles (Mon…Sun) for the "Custom" frequency,
/// keyed by [DateTime.weekday] values (1 = Monday … 7 = Sunday).
class _CustomDayPicker extends StatelessWidget {
  final Set<int> selected;
  final Color color;
  final ValueChanged<int> onToggle;

  const _CustomDayPicker({required this.selected, required this.color, required this.onToggle});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (int day = 1; day <= 7; day++)
          GestureDetector(
            onTap: () => onToggle(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected.contains(day) ? color : Colors.transparent,
                border: Border.all(
                  color: selected.contains(day) ? color : colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Text(
                _labels[day - 1],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected.contains(day) ? Colors.white : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
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