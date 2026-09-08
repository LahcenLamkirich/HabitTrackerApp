import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/services.dart';

/// Global service singletons. Initialized once in main.dart before runApp.
late final StorageService storage;
late final NotificationService notifications;
late final DayResetService dayReset;

/// Provider: the StorageService instance.
@override
final storageProvider = Provider<StorageService>((ref) => storage);

/// Provider: the NotificationService instance.
@override
final notificationProvider =
    Provider<NotificationService>((ref) => notifications);

/// Provider: the DayResetService instance.
@override
final dayResetProvider =
    Provider<DayResetService>((ref) => dayReset);

// ──────────────────────────────────────────────────────────────────
// Settings
// ──────────────────────────────────────────────────────────────────

/// Notifier for the global [Settings].
class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => storage.settings;

  Future<void> setNotificationsEnabled(bool value) async {
    final next = state.copyWith(notificationsEnabled: value);
    await _save(next);
    if (value) {
      await notifications.rescheduleAll(
        storage.activeTasks,
        settings: next,
      );
    } else {
      await notifications.cancelAll();
    }
  }

  Future<void> setDefaultReminderTime(TimeOfDay? value) async {
    final next = state.copyWith(
      defaultReminderTime: value,
      clearDefaultReminder: value == null,
    );
    await _save(next);
  }

  Future<void> setDayResetHour(int hour) async {
    final next = state.copyWith(dayResetHour: hour);
    await _save(next);
    dayReset.forceCheck();
  }

  Future<void> setFollowUpHours(int? hours) async {
    final next = state.copyWith(
      followUpAfterHours: hours,
      clearFollowUp: hours == null,
    );
    await _save(next);
  }

  Future<void> _save(Settings settings) async {
    await storage.saveSettings(settings);
    state = settings;
  }
}

@override
final settingsProvider =
    NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ──────────────────────────────────────────────────────────────────
// Tasks
// ──────────────────────────────────────────────────────────────────

/// Refresh trigger — incrementing this invalidates the tasks cache.
@override
final tasksVersionProvider = StateProvider<int>((ref) => 0);

/// All active tasks, in insertion order.
@override
final activeTasksProvider = Provider<List<Task>>((ref) {
  ref.watch(tasksVersionProvider);
  return storage.activeTasks;
});

/// All tasks (including paused).
@override
final allTasksProvider = Provider<List<Task>>((ref) {
  ref.watch(tasksVersionProvider);
  return storage.allTasks;
});

/// Active tasks scheduled for today, per each task's [Task.activeWeekdays]
/// — what the Today checklist should actually show.
@override
final todayScheduledTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(activeTasksProvider);
  final today = DateTime.now();
  return tasks.where((t) => t.isScheduledOn(today)).toList();
});

/// Notifier for task mutations (add, update, delete, toggle, skip).
class TaskNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<Task> addTask({
    required String name,
    String? icon,
    String? notes,
    TimeOfDay? reminderTime,
    List<int>? activeWeekdays,
  }) async {
    final settings = ref.read(settingsProvider);
    final task = await storage.addTask(
      name: name,
      icon: icon,
      notes: notes,
      reminderTime: reminderTime ?? settings.defaultReminderTime,
      activeWeekdays: activeWeekdays,
    );

    // Schedule notification if applicable.
    await notifications.scheduleDailyReminder(
      task,
      notificationsEnabled: settings.notificationsEnabled,
    );

    // Follow-up scheduling.
    if (settings.followUpAfterHours != null && task.hasReminder) {
      await notifications.scheduleFollowUp(
        task,
        hours: settings.followUpAfterHours!,
        notificationsEnabled: settings.notificationsEnabled,
      );
    }

    ref.read(tasksVersionProvider.notifier).state++;
    return task;
  }

  Future<void> updateTask(Task task) async {
    await storage.updateTask(task);
    final settings = ref.read(settingsProvider);
    await notifications.scheduleDailyReminder(
      task,
      notificationsEnabled: settings.notificationsEnabled,
    );
    ref.read(tasksVersionProvider.notifier).state++;
  }

  Future<void> deleteTask(String id) async {
    await notifications.cancelForTask(id);
    await storage.deleteTask(id);
    ref.read(tasksVersionProvider.notifier).state++;
  }

  Future<void> setTaskActive(String id, bool isActive) async {
    await storage.setTaskActive(id, isActive);
    if (!isActive) {
      await notifications.cancelForTask(id);
    } else {
      final task = storage.getTask(id);
      if (task != null) {
        final settings = ref.read(settingsProvider);
        await notifications.scheduleDailyReminder(
          task,
          notificationsEnabled: settings.notificationsEnabled,
        );
      }
    }
    ref.read(tasksVersionProvider.notifier).state++;
  }

  /// Mark a task as done for today (or a specific date).
  Future<void> markDone(String taskId, {DateTime? date}) async {
    final target = date ?? DateTime.now();
    await storage.markDone(taskId, target);
    // Cancel any pending follow-up.
    await notifications.cancelFollowUp(taskId);
    // Invalidate log caches.
    ref.invalidate(todayLogsProvider);
    ref.invalidate(logsForDateProvider);
    ref.invalidate(taskStreakProvider(taskId));
  }

  /// Mark a task as skipped for today.
  Future<void> markSkipped(String taskId, {DateTime? date}) async {
    final target = date ?? DateTime.now();
    await storage.markSkipped(taskId, target);
    await notifications.cancelFollowUp(taskId);
    ref.invalidate(todayLogsProvider);
    ref.invalidate(logsForDateProvider);
    ref.invalidate(taskStreakProvider(taskId));
  }

  /// Undo a done/skipped action — clear today's log for this task.
  Future<void> undoToday(String taskId) async {
    final now = DateTime.now();
    await storage.clearLog(taskId, now);
    // Reschedule follow-up if a reminder is set.
    final task = storage.getTask(taskId);
    if (task != null) {
      final settings = ref.read(settingsProvider);
      if (settings.followUpAfterHours != null && task.hasReminder) {
        await notifications.scheduleFollowUp(
          task,
          hours: settings.followUpAfterHours!,
          notificationsEnabled: settings.notificationsEnabled,
        );
      }
    }
    ref.invalidate(todayLogsProvider);
    ref.invalidate(logsForDateProvider);
    ref.invalidate(taskStreakProvider(taskId));
  }
}

@override
final taskNotifierProvider =
    NotifierProvider<TaskNotifier, void>(TaskNotifier.new);

// ──────────────────────────────────────────────────────────────────
// Logs & status
// ──────────────────────────────────────────────────────────────────

/// All today's logs, keyed by taskId.
@override
final todayLogsProvider = Provider<Map<String, TaskLog>>((ref) {
  ref.watch(tasksVersionProvider);
  final logs = storage.getLogsForDate(DateTime.now());
  return {for (final log in logs) log.taskId: log};
});

/// Logs for a specific date (calendar / history).
@override
final logsForDateProvider =
    Provider.family<List<TaskLog>, DateTime>((ref, date) {
  ref.watch(tasksVersionProvider);
  return storage.getLogsForDate(date);
});

/// Effective status for a task on a given date.
@override
final taskStatusProvider =
    Provider.family<TaskStatus, (String taskId, DateTime date)>((ref, params) {
  ref.watch(todayLogsProvider);
  final task = storage.getTask(params.$1);
  if (task == null) return TaskStatus.pending;
  return storage.getTaskStatus(task, params.$2, ref.read(settingsProvider));
});

/// Streak for a specific task.
@override
final taskStreakProvider =
    Provider.family<int, String>((ref, taskId) {
  ref.watch(todayLogsProvider);
  return storage.getStreak(taskId);
});

// ──────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────

/// A display-friendly map of today's taskId → TaskStatus.
@override
final todayTaskStatusesProvider = Provider<Map<String, TaskStatus>>((ref) {
  final logs = ref.watch(todayLogsProvider);
  final tasks = ref.watch(activeTasksProvider);
  final settings = ref.read(settingsProvider);
  final today = DateTime.now();

  return {
    for (final task in tasks)
      task.id: storage.getTaskStatus(task, today, settings),
  };
});