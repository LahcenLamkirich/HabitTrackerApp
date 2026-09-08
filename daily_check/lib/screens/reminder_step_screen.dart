import 'package:flutter/material.dart';

/// Marker value [ReminderStepScreen] pops with when the user explicitly
/// chooses to skip setting a reminder — as opposed to backing out of the
/// step entirely (which pops with `null` and means "go back, don't
/// finish creating the habit yet").
class ReminderSkipped {
  const ReminderSkipped();
}

/// Step 2 of the "new habit" flow: an optional, skippable screen that asks
/// the user to pick a reminder time for the habit they just described in
/// step 1, so it's clear a reminder can be set without forcing one.
///
/// Pops with:
///  - a [TimeOfDay] if the user picked and confirmed a time
///  - a [ReminderSkipped] if the user explicitly skipped or confirmed with
///    no time chosen
///  - `null` if the user backed out via the back button (the caller should
///    stay on the previous step, not finish creating the habit)
class ReminderStepScreen extends StatefulWidget {
  final String habitName;
  final Color accent;
  final TimeOfDay? initialTime;

  const ReminderStepScreen({
    super.key,
    required this.habitName,
    required this.accent,
    this.initialTime,
  });

  @override
  State<ReminderStepScreen> createState() => _ReminderStepScreenState();
}

class _ReminderStepScreenState extends State<ReminderStepScreen> {
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _finish() => Navigator.of(context).pop(_time ?? const ReminderSkipped());

  void _skip() => Navigator.of(context).pop(const ReminderSkipped());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = widget.accent;
    final displayName = widget.habitName.trim().isEmpty ? 'this habit' : widget.habitName.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _skip,
            child: Text(
              'Skip',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  _StepDot(color: accent),
                  const SizedBox(width: 6),
                  _StepDot(color: accent),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'STEP 2 OF 2',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.notifications_active_rounded, color: accent, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Set a reminder',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Get a gentle nudge to check off "$displayName". This is completely optional — skip it any time.',
                style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _pickTime,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: accent.withValues(alpha: _time == null ? 0.25 : 0.55),
                      width: _time == null ? 1 : 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.alarm_rounded, size: 32, color: accent),
                      const SizedBox(height: 10),
                      Text(
                        _time == null ? 'No reminder yet' : _time!.format(context),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _time == null ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _time == null ? 'Tap to choose a time' : 'Tap to change',
                        style: theme.textTheme.bodySmall?.copyWith(color: accent, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.75)]),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: ElevatedButton(
              onPressed: _finish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _time == null ? 'Continue Without Reminder' : 'Set Reminder & Finish',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final Color color;
  const _StepDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 5,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
    );
  }
}
