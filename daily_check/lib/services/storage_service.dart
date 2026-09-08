import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

/// The single source of truth for all persisted data in Daily Check.
///
/// Implements a repository pattern over Hive boxes. This service is the
/// only class that directly touches Hive — all other code goes through
/// this service, making it easy to swap storage backends later.
///
/// ## Box layout
///   - `tasks` box  → stores [Task] objects keyed by task.id
///   - `logs` box   → stores [TaskLog] objects keyed by "${taskId}_${dateStr}"
///   - `settings`  → singleton [Settings] at key 'settings'
///
/// ## Thread-safety
/// All public methods are synchronous (Hive's default mode) but must be
/// called after [init] has completed. In production, avoid running them
/// on the UI thread for very large datasets (consider using Hive's
/// async API instead for the logs box with thousands of entries).
class StorageService {
  static const String _tasksBoxName = 'tasks';
  static const String _logsBoxName = 'logs';
  static const String _settingsBoxName = 'settings';
  static const String _settingsKey = 'settings';

  late Box<Task> _tasksBox;
  late Box<TaskLog> _logsBox;
  late Box<Settings> _settingsBox;

  final Uuid _uuid = const Uuid();

  // ──────────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────────

  /// Initialize Hive and register all adapters. Call this exactly once
  /// in [main] before [runApp].
  static Future<StorageService> init() async {
    await Hive.initFlutter();

    // Register type adapters before opening any box.
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(TaskLogAdapter());
    Hive.registerAdapter(LogStatusAdapter());
    Hive.registerAdapter(TimeOfDayAdapter());
    Hive.registerAdapter(SettingsAdapter());

    final service = StorageService();
    await service._openBoxes();
    await service._ensureSettings();
    await service._seedSampleTasksIfEmpty();

    return service;
  }

  Future<void> _openBoxes() async {
    _tasksBox = await Hive.openBox<Task>(_tasksBoxName);
    _logsBox = await Hive.openBox<TaskLog>(_logsBoxName);
    _settingsBox = await Hive.openBox<Settings>(_settingsBoxName);
  }

  Future<void> _ensureSettings() async {
    if (!_settingsBox.containsKey(_settingsKey)) {
      await _settingsBox.put(_settingsKey, Settings());
    }
  }

  /// Seed the app with sensible defaults on first launch so it's not empty.
  Future<void> _seedSampleTasksIfEmpty() async {
    if (_tasksBox.isNotEmpty) return;

    final sampleTasks = [
      Task(
        id: _uuid.v4(),
        name: 'Take creatine',
        notes: '1 scoop',
        icon: 'supplements',
        reminderTime: const TimeOfDay(hour: 8, minute: 0),
        isActive: true,
      ),
      Task(
        id: _uuid.v4(),
        name: 'Drink water',
        notes: '8 glasses',
        icon: 'water',
        reminderTime: null, // reset at midnight
        isActive: true,
      ),
      Task(
        id: _uuid.v4(),
        name: 'Stretch',
        notes: '5–10 minutes',
        icon: 'fitness',
        reminderTime: const TimeOfDay(hour: 9, minute: 0),
        isActive: true,
      ),
      Task(
        id: _uuid.v4(),
        name: 'Take vitamins',
        notes: 'With breakfast',
        icon: 'medication',
        reminderTime: const TimeOfDay(hour: 7, minute: 30),
        isActive: true,
      ),
    ];

    for (final task in sampleTasks) {
      await _tasksBox.put(task.id, task);
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Task CRUD
  // ──────────────────────────────────────────────────────────────────

  /// All active tasks in insertion order.
  List<Task> get activeTasks {
    return _tasksBox.values.where((t) => t.isActive).toList();
  }

  /// All tasks (active and paused).
  List<Task> get allTasks {
    return _tasksBox.values.toList();
  }

  /// Get a single task by id, or null if not found.
  Task? getTask(String id) {
    return _tasksBox.get(id);
  }

  /// Add a new task. The id is auto-generated with a UUID.
  Future<Task> addTask({
    required String name,
    String? icon,
    String? notes,
    TimeOfDay? reminderTime,
    bool isActive = true,
    List<int>? activeWeekdays,
  }) async {
    final task = Task(
      id: _uuid.v4(),
      name: name,
      icon: icon,
      notes: notes,
      reminderTime: reminderTime,
      isActive: isActive,
      activeWeekdays: activeWeekdays,
    );
    await _tasksBox.put(task.id, task);
    return task;
  }

  /// Update an existing task (replaces the entry in the box).
  Future<void> updateTask(Task task) async {
    await _tasksBox.put(task.id, task);
  }

  /// Delete a task and all its logs.
  Future<void> deleteTask(String id) async {
    await _tasksBox.delete(id);
    // Remove all logs for this task.
    final keysToDelete = _logsBox.keys
        .where((k) => k is String && k.startsWith('${id}_'))
        .toList();
    for (final k in keysToDelete) {
      await _logsBox.delete(k);
    }
  }

  /// Pause or unpause a task (keeps history intact).
  Future<void> setTaskActive(String id, bool isActive) async {
    final task = _tasksBox.get(id);
    if (task != null) {
      await _tasksBox.put(id, task.copyWith(isActive: isActive));
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // TaskLog operations
  // ──────────────────────────────────────────────────────────────────

  /// Key used to store a log entry: "${taskId}_$dateStr".
  String _logKey(String taskId, DateTime date) {
    return '${taskId}_${_dateKey(date)}';
  }

  /// YYYY-MM-DD string for a date (local time).
  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Get the log for a specific task on a specific date.
  TaskLog? getLog(String taskId, DateTime date) {
    return _logsBox.get(_logKey(taskId, date));
  }

  /// Get all logs for a specific task.
  List<TaskLog> getLogsForTask(String taskId) {
    return _logsBox.values.where((log) => log.taskId == taskId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Get all logs for a specific date (for the History screen calendar).
  List<TaskLog> getLogsForDate(DateTime date) {
    return _logsBox.values.where((log) => _dateKey(log.date) == _dateKey(date)).toList();
  }

  /// Mark a task as done for the current day.
  Future<void> markDone(String taskId, DateTime date) async {
    await _logsBox.put(
      _logKey(taskId, date),
      TaskLog.done(taskId: taskId, date: _startOfDay(date)),
    );
  }

  /// Mark a task as skipped for the current day.
  Future<void> markSkipped(String taskId, DateTime date) async {
    await _logsBox.put(
      _logKey(taskId, date),
      TaskLog.skipped(taskId: taskId, date: _startOfDay(date)),
    );
  }

  /// Clear today's log for a task (undo).
  Future<void> clearLog(String taskId, DateTime date) async {
    await _logsBox.delete(_logKey(taskId, date));
  }

  /// Return the effective [TaskStatus] for a task on a given date,
  /// accounting for the reminder time if set.
  TaskStatus getTaskStatus(
    Task task,
    DateTime date,
    Settings settings,
  ) {
    final log = getLog(task.id, date);
    if (log != null) {
      return log.toTaskStatus();
    }

    // Off-schedule days never count as missed — there was nothing due.
    if (!task.isScheduledOn(date)) {
      return TaskStatus.pending;
    }

    // No log yet — check if we're past the reminder time today.
    final now = DateTime.now();
    final today = _startOfDay(now);
    final targetDay = _startOfDay(date);

    if (targetDay == today && task.hasReminder) {
      final reminderMinute = task.reminderTime!.hour * 60 + task.reminderTime!.minute;
      final nowMinute = now.hour * 60 + now.minute;
      if (nowMinute > reminderMinute) {
        return TaskStatus.missed;
      }
    }

    return TaskStatus.pending;
  }

  // ──────────────────────────────────────────────────────────────────
  // Streak calculation
  // ──────────────────────────────────────────────────────────────────

  /// Calculate the current streak (consecutive scheduled days done) for a
  /// task. Days the task isn't scheduled on (per [Task.activeWeekdays])
  /// are skipped over rather than breaking the chain — a "Weekdays" habit
  /// isn't penalized for weekends.
  int getStreak(String taskId) {
    final task = getTask(taskId);
    if (task == null || task.activeWeekdays.isEmpty) return 0;

    final doneDates = getLogsForTask(taskId)
        .where((l) => l.status == LogStatus.done)
        .map((l) => _startOfDay(l.date))
        .toSet();

    if (doneDates.isEmpty) return 0;

    int streak = 0;
    DateTime checkDate = _startOfDay(DateTime.now());

    // If today is scheduled but not done yet, start from yesterday.
    if (task.isScheduledOn(checkDate) && !doneDates.contains(checkDate)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Safety bound so a data anomaly can't spin this into an infinite loop.
    final earliestPossible = doneDates.reduce((a, b) => a.isBefore(b) ? a : b).subtract(const Duration(days: 7));

    while (checkDate.isAfter(earliestPossible)) {
      if (!task.isScheduledOn(checkDate)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      if (doneDates.contains(checkDate)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  // ──────────────────────────────────────────────────────────────────
  // Settings
  // ──────────────────────────────────────────────────────────────────

  /// The app's current settings (never null).
  Settings get settings => _settingsBox.get(_settingsKey) ?? Settings();

  /// Persist a new settings object.
  Future<void> saveSettings(Settings settings) async {
    await _settingsBox.put(_settingsKey, settings);
  }

  // ──────────────────────────────────────────────────────────────────
  // Day-reset helpers
  // ──────────────────────────────────────────────────────────────────

  /// Given a local DateTime, return the start of the logical "day"
  /// as defined by [Settings.dayResetHour].
  ///
  /// For example, with dayResetHour = 4:
  ///   - 3am Jan 15 → day starts on Jan 14
  ///   - 5am Jan 15 → day starts on Jan 15
  DateTime getLogicalDay(DateTime localTime, Settings settings) {
    final resetTime = settings.dayResetTime;
    final cutoff = DateTime(
      localTime.year,
      localTime.month,
      localTime.day,
      resetTime.hour,
      resetTime.minute,
    );

    if (localTime.isBefore(cutoff)) {
      return cutoff.subtract(const Duration(days: 1));
    }
    return cutoff;
  }

  /// Start-of-day for a given DateTime (midnight local).
  DateTime _startOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }
}