import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/services.dart';
import '../widgets/screen_title.dart';

/// The Profile / Settings screen — an animated header summarizing the
/// user's habits at a glance, followed by grouped setting cards with
/// colored icon badges instead of plain list tiles.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tasks = ref.watch(activeTasksProvider);
    final bestStreak = tasks.isEmpty
        ? 0
        : tasks
            .map((t) => ref.watch(taskStreakProvider(t.id)))
            .fold<int>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          children: [
            const ScreenTitle(
              icon: Icons.person_rounded,
              color: Color(0xFF6C63FF),
              title: 'Profile',
              subtitle: 'Manage habits, reminders & preferences',
            ),
            const SizedBox(height: 16),
            _ProfileHeader(
              controller: _entrance,
              habitCount: tasks.length,
              bestStreak: bestStreak,
            ),
            const SizedBox(height: 24),
  
            _AnimatedSection(
              controller: _entrance,
              index: 0,
              title: 'Notifications',
              children: [
                _SettingTile(
                  icon: Icons.notifications_rounded,
                  iconColor: const Color(0xFFE85D30),
                  title: 'Enable reminders',
                  subtitle: 'Show daily reminder notifications',
                  trailing: Switch.adaptive(
                    value: settings.notificationsEnabled,
                    onChanged: (value) {
                      ref
                          .read(settingsProvider.notifier)
                          .setNotificationsEnabled(value);
                    },
                  ),
                ),
                _SettingTile(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: const Color(0xFF3A86FF),
                  title: 'Default reminder time',
                  subtitle: settings.defaultReminderTime == null
                      ? 'Not set (use per-task)'
                      : _formatTime(settings.defaultReminderTime!),
                  trailing: settings.defaultReminderTime != null
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            ref
                                .read(settingsProvider.notifier)
                                .setDefaultReminderTime(null);
                          },
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: settings.defaultReminderTime ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      ref
                          .read(settingsProvider.notifier)
                          .setDefaultReminderTime(picked);
                    }
                  },
                ),
                _SettingTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: const Color(0xFFFFB703),
                  title: 'Follow-up reminder',
                  subtitle: settings.followUpAfterHours == null
                      ? 'Off'
                      : '${settings.followUpAfterHours} hours after reminder',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await _showFollowUpPicker(
                        context, ref, settings.followUpAfterHours);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
  
            _AnimatedSection(
              controller: _entrance,
              index: 1,
              title: 'Day reset',
              children: [
                _SettingTile(
                  icon: Icons.calendar_today_rounded,
                  iconColor: const Color(0xFF2EC4B6),
                  title: 'Day starts at',
                  subtitle: _formatHour(settings.dayResetHour),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await _showHourPicker(context, ref, settings.dayResetHour);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
  
            _AnimatedSection(
              controller: _entrance,
              index: 2,
              title: 'Your data',
              children: [
                _SettingTile(
                  icon: Icons.ios_share_rounded,
                  iconColor: const Color(0xFF3D8BFD),
                  title: 'Back up my habits',
                  subtitle: 'Save a copy of every habit and streak',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _exportBackup,
                ),
                _SettingTile(
                  icon: Icons.restore_rounded,
                  iconColor: const Color(0xFFF4A261),
                  title: 'Restore from a backup',
                  subtitle: 'Replaces everything currently in the app',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _importBackup,
                ),
              ],
            ),
            const SizedBox(height: 16),

            _AnimatedSection(
              controller: _entrance,
              index: 3,
              title: 'About',
              children: [
                _SettingTile(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: const Color(0xFFEF476F),
                  title: 'Daily Check',
                  subtitle: 'Version 1.0.0',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // Backup / restore
  // ──────────────────────────────────────────────────────────────────

  Future<void> _exportBackup() async {
    try {
      final saved = await ref.read(backupProvider).exportToFile();
      if (!saved || !mounted) return;
      _showMessage("Backup saved.");
    } catch (e) {
      if (!mounted) return;
      _showMessage("Couldn't create the backup: $e", isError: true);
    }
  }

  Future<void> _importBackup() async {
    // Restoring throws away whatever is in the app right now, so it needs an
    // explicit yes before the file picker even opens.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from a backup?'),
        content: const Text(
          'This replaces every habit and all history currently in Daily Check '
          'with the contents of the backup file. It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final result = await ref.read(backupProvider).pickAndImport();
      if (result == null) return; // user cancelled the picker

      // Storage changed underneath every provider, so rebuild the world and
      // re-arm notifications for the habits that just arrived.
      ref.invalidate(settingsProvider);
      ref.read(tasksVersionProvider.notifier).state++;
      await ref.read(notificationProvider).rescheduleAll(
            storage.activeTasks,
            settings: storage.settings,
          );

      if (!mounted) return;
      _showMessage('Restored ${result.tasks} habits '
          'and ${result.logs} days of history.');
    } on BackupFormatException catch (e) {
      if (!mounted) return;
      _showMessage(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage("Couldn't restore that backup: $e", isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? const Color(0xFFB3261E) : null,
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${t.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatHour(int hour) {
    if (hour == 0) return 'Midnight (12:00 AM)';
    if (hour == 12) return 'Noon (12:00 PM)';
    if (hour < 12) return '$hour:00 AM';
    return '${hour - 12}:00 PM';
  }

  Future<void> _showFollowUpPicker(
    BuildContext context,
    WidgetRef ref,
    int? current,
  ) async {
    final options = [null, 1, 2, 3, 4, 6, 8, 12, 24];
    final labels = [
      'Off',
      '1 hour',
      '2 hours',
      '3 hours',
      '4 hours',
      '6 hours',
      '8 hours',
      '12 hours',
      '24 hours',
    ];

    final picked = await showDialog<int?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Follow-up reminder'),
        children: [
          for (int i = 0; i < options.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(options[i]),
              child: Row(
                children: [
                  if (options[i] == current)
                    Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  else
                    const SizedBox(width: 24),
                  const SizedBox(width: 12),
                  Text(labels[i]),
                ],
              ),
            ),
        ],
      ),
    );

    if (picked != null) {
      ref.read(settingsProvider.notifier).setFollowUpHours(picked);
    }
  }

  Future<void> _showHourPicker(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final options = [0, 1, 2, 3, 4, 5, 6];
    final labels = ['Midnight (12 AM)', '1 AM', '2 AM', '3 AM', '4 AM', '5 AM', '6 AM'];

    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Day starts at'),
        children: [
          for (int i = 0; i < options.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(options[i]),
              child: Row(
                children: [
                  if (options[i] == current)
                    Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                  else
                    const SizedBox(width: 24),
                  const SizedBox(width: 12),
                  Text(labels[i]),
                ],
              ),
            ),
        ],
      ),
    );

    if (picked != null) {
      ref.read(settingsProvider.notifier).setDayResetHour(picked);
    }
  }
}

/// Header card with a glowing avatar, a pulsing flame badge for the best
/// streak, and a couple of quick stats — fades and slides in on load.
class _ProfileHeader extends StatelessWidget {
  final AnimationController controller;
  final int habitCount;
  final int bestStreak;

  const _ProfileHeader({
    required this.controller,
    required this.habitCount,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    final slide = Tween<Offset>(
      begin: const Offset(0, -0.08),
      end: Offset.zero,
    ).animate(fade);
    const primary = Color(0xFFE85D30);
    const secondary = Color(0xFFFF8A65);

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [secondary, primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _PulsingAvatar(controller: controller),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keep it up!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      habitCount == 0
                          ? 'No habits yet'
                          : 'Tracking $habitCount habit${habitCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Best streak: $bestStreak days',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PulsingAvatar extends StatefulWidget {
  final AnimationController controller;

  const _PulsingAvatar({required this.controller});

  @override
  State<_PulsingAvatar> createState() => _PulsingAvatarState();
}

class _PulsingAvatarState extends State<_PulsingAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final scale = 1.0 + (_pulse.value * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
        ),
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 32),
      ),
    );
  }
}

/// A settings card that fades and slides up, staggered by [index].
class _AnimatedSection extends StatelessWidget {
  final AnimationController controller;
  final int index;
  final String title;
  final List<Widget> children;

  const _AnimatedSection({
    required this.controller,
    required this.index,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final start = (0.15 * index).clamp(0.0, 0.6);
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(anim);

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: slide,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  for (int i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1)
                      const Divider(height: 1, indent: 60),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single settings row with a colored, rounded icon badge.
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}
