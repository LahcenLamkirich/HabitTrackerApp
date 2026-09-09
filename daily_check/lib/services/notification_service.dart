import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Wraps `flutter_local_notifications` and exposes a small, app-specific
/// surface for the rest of the app.
///
/// Responsibilities:
///   1. Initialize the plugin (timezone + platform channels).
///   2. Schedule a daily reminder for a task at a specific time.
///   3. Schedule a one-shot follow-up reminder.
///   4. Cancel notifications when a task is updated, deleted, paused,
///      or marked done.
///
/// Notification IDs are deterministic so we can re-schedule by simply
/// rescheduling the same id: id = task.id.hashCode & 0x7FFFFFFF.
///
/// On web, all scheduling methods are no-ops since flutter_local_notifications
/// is not supported there. The app still works — just without push reminders.
class NotificationService {
  static const String _channelId = 'daily_check_reminders';
  static const String _channelName = 'Daily Check Reminders';
  static const String _channelDescription =
      'Reminders for your daily habit tasks';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // ──────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────

  /// Initialize the plugin and timezone. Call once on app start.
  Future<void> init() async {
    if (_initialized) return;

    // Notifications are not supported on web — short-circuit.
    if (kIsWeb) {
      _initialized = true;
      return;
    }

    tz_data.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _plugin.initialize(initSettings);

    // Android 13+ requires runtime permission.
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  /// Compute a deterministic, low-order positive hash for a task, reserved
  /// to the low 20 bits so it can be combined with weekday/kind flags above
  /// it without ever colliding.
  int _baseIdForTask(String taskId) {
    return taskId.hashCode & 0x000FFFFF;
  }

  /// Notification id for the daily-reminder occurrence on a specific
  /// [weekday] (1 = Monday … 7 = Sunday). Each weekday gets its own
  /// scheduled notification so a habit's active-days schedule (e.g.
  /// "Weekends only") is actually respected.
  int _reminderIdForWeekday(String taskId, int weekday) {
    return 0x01000000 | (weekday << 20) | _baseIdForTask(taskId);
  }

  /// Notification id for the one-shot follow-up reminder.
  int _followUpIdForTask(String taskId) {
    return 0x40000000 | _baseIdForTask(taskId);
  }

  // ──────────────────────────────────────────────────────────────────
  // Permissions / global settings
  // ──────────────────────────────────────────────────────────────────

  /// Check whether notifications are currently enabled at the OS level.
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (!_initialized) await init();

    try {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await androidImpl?.areNotificationsEnabled();
      if (enabled != null) return enabled;

      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final perms = await iosImpl?.checkPermissions();
      if (perms == null) return false;
      return perms.isAlertEnabled ||
          perms.isBadgeEnabled ||
          perms.isSoundEnabled;
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Scheduling
  // ──────────────────────────────────────────────────────────────────

  /// Schedule a single daily reminder for a task.
  /// No-op on web or when notifications are disabled globally.
  Future<void> scheduleDailyReminder(
    Task task, {
    required bool notificationsEnabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await cancelForTask(task.id);

    if (!notificationsEnabled) return;
    if (!task.isActive) return;
    if (task.reminderTime == null) return;

    // Schedule one recurring notification per active weekday so habits
    // that only run on e.g. weekends don't get pinged every day.
    for (final weekday in task.activeWeekdays) {
      final time = _nextInstanceOfWeekdayAndTime(weekday, task.reminderTime!);
      final id = _reminderIdForWeekday(task.id, weekday);

      try {
        await _plugin.zonedSchedule(
          id,
          task.name,
          task.notes ?? 'Time for your daily check',
          time,
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Failed to schedule reminder for ${task.id}: $e');
        }
      }
    }
  }

  /// Schedule a one-shot follow-up reminder N hours from now.
  Future<void> scheduleFollowUp(
    Task task, {
    required int hours,
    required bool notificationsEnabled,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await cancelFollowUp(task.id);

    if (!notificationsEnabled) return;
    if (!task.isActive) return;
    if (hours <= 0) return;

    final time = tz.TZDateTime.now(tz.local).add(Duration(hours: hours));
    final id = _followUpIdForTask(task.id);

    try {
      await _plugin.zonedSchedule(
        id,
        '${task.name} (reminder)',
        task.notes ?? "You haven't marked this done yet",
        time,
        _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to schedule follow-up for ${task.id}: $e');
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Cancellation
  // ──────────────────────────────────────────────────────────────────

  Future<void> cancelForTask(String taskId) async {
    if (kIsWeb) return;
    for (final weekday in kAllWeekdays) {
      await _plugin.cancel(_reminderIdForWeekday(taskId, weekday));
    }
    await _plugin.cancel(_followUpIdForTask(taskId));
  }

  Future<void> cancelFollowUp(String taskId) async {
    if (kIsWeb) return;
    await _plugin.cancel(_followUpIdForTask(taskId));
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  // ──────────────────────────────────────────────────────────────────
  // Re-schedule all
  // ──────────────────────────────────────────────────────────────────

  Future<void> rescheduleAll(
    List<Task> tasks, {
    required Settings settings,
  }) async {
    if (kIsWeb) return;
    if (!_initialized) await init();
    await cancelAll();

    if (!settings.notificationsEnabled) return;

    for (final task in tasks) {
      await scheduleDailyReminder(
        task,
        notificationsEnabled: settings.notificationsEnabled,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Internal helpers
  // ──────────────────────────────────────────────────────────────────

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  /// Next occurrence of [time] on the given [weekday] (1 = Monday …
  /// 7 = Sunday), using [DateTime.weekday] numbering.
  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
