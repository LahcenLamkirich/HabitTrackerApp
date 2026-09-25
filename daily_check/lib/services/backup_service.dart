import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'storage_service.dart';

/// Thrown when an import file cannot be understood or is not a Daily Check
/// backup. The [message] is written for the user, not the developer.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);

  @override
  String toString() => message;
}

/// A summary of what an import brought in, so the UI can tell the user.
class ImportResult {
  final int tasks;
  final int logs;
  const ImportResult({required this.tasks, required this.logs});
}

/// Exports and restores the user's habits and history as a JSON file.
///
/// All Daily Check data lives on-device in Hive, so an uninstall or a lost
/// phone would otherwise destroy every streak the user has built. This
/// service is the user's only escape hatch, so it favours being explicit
/// and lossless over being clever:
///
///   * Export writes every task, every log and the settings, plus a schema
///     version so a future format change can migrate old files.
///   * Import *replaces* the current contents rather than merging, because
///     merging two divergent histories has no single correct answer. The
///     UI is responsible for confirming this with the user first.
class BackupService {
  /// Bumped whenever the on-disk shape changes in a way importers must know
  /// about. Readers must refuse a version they do not understand rather
  /// than guessing.
  static const int schemaVersion = 1;

  static const String _magic = 'daily_check_backup';

  final StorageService _storage;

  BackupService(this._storage);

  // ──────────────────────────────────────────────────────────────────
  // Export
  // ──────────────────────────────────────────────────────────────────

  /// Build the backup document. Kept separate from file/share handling so
  /// it can be unit tested without a platform channel.
  Map<String, dynamic> buildBackup() {
    final tasks = _storage.allTasks;
    final settings = _storage.settings;

    return {
      'format': _magic,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': _settingsToJson(settings),
      'tasks': [
        for (final task in tasks) _taskToJson(task),
      ],
      'logs': [
        // Logs are fetched per task so the export never depends on the
        // internal log-key format.
        for (final task in tasks)
          for (final log in _storage.getLogsForTask(task.id)) _logToJson(log),
      ],
    };
  }

  /// Serialise a backup to pretty-printed JSON.
  String encodeBackup() {
    return const JsonEncoder.withIndent('  ').convert(buildBackup());
  }

  /// A stable, sortable filename like `daily-check-backup-2026-09-25.json`.
  String suggestedFileName([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return 'daily-check-backup-$y-$m-$day.json';
  }

  /// Ask the user where to save the backup and write it there.
  ///
  /// Returns false if the user dismissed the save dialog. Uses the platform
  /// save dialog (Android's storage picker, Files on iOS) rather than writing
  /// into app-private storage, so the file survives an uninstall — which is
  /// the entire point of taking a backup.
  Future<bool> exportToFile() async {
    final bytes = utf8.encode(encodeBackup());
    final uri = await FilePicker.saveFile(
      fileName: suggestedFileName(),
      bytes: bytes,
      mimeType: 'application/json',
      dialogTitle: 'Save Daily Check backup',
    );
    return uri != null;
  }

  // ──────────────────────────────────────────────────────────────────
  // Import
  // ──────────────────────────────────────────────────────────────────

  /// Let the user pick a backup file and restore it, replacing all current
  /// data. Returns null if the user cancelled the picker.
  Future<ImportResult?> pickAndImport() async {
    final file = await FilePicker.pickFile(
      type: FileType.any,
      dialogTitle: 'Choose a Daily Check backup',
    );
    if (file == null) return null;

    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      throw const BackupFormatException("That file couldn't be read.");
    }

    return importFromJson(utf8.decode(bytes, allowMalformed: true));
  }

  /// Parse and apply a backup document. Validates before it writes anything,
  /// so a malformed file cannot leave storage half-replaced.
  Future<ImportResult> importFromJson(String source) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const BackupFormatException(
          "That file isn't valid JSON, so it isn't a Daily Check backup.");
    }

    if (decoded is! Map<String, dynamic> || decoded['format'] != _magic) {
      throw const BackupFormatException(
          "That file isn't a Daily Check backup.");
    }

    final version = decoded['schemaVersion'];
    if (version is! int || version > schemaVersion) {
      throw const BackupFormatException(
          'That backup was made by a newer version of Daily Check. '
          'Update the app and try again.');
    }

    // Parse everything up front: if any record is broken we abort before
    // touching the user's existing data.
    final List<Task> tasks;
    final List<TaskLog> logs;
    try {
      tasks = [
        for (final raw in (decoded['tasks'] as List? ?? const []))
          _taskFromJson(raw as Map<String, dynamic>),
      ];
      logs = [
        for (final raw in (decoded['logs'] as List? ?? const []))
          _logFromJson(raw as Map<String, dynamic>),
      ];
    } catch (_) {
      throw const BackupFormatException(
          'That backup looks damaged and could not be restored.');
    }

    final settingsRaw = decoded['settings'];
    final settings = settingsRaw is Map<String, dynamic>
        ? _settingsFromJson(settingsRaw)
        : null;

    await _storage.replaceAll(tasks: tasks, logs: logs, settings: settings);

    return ImportResult(tasks: tasks.length, logs: logs.length);
  }

  // ──────────────────────────────────────────────────────────────────
  // JSON mapping
  //
  // Written by hand rather than generated so the file format is decoupled
  // from the Hive field numbering: changing storage internals must not
  // silently change the export.
  // ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> _taskToJson(Task t) => {
        'id': t.id,
        'name': t.name,
        'icon': t.icon,
        'notes': t.notes,
        'reminderTime': _timeToJson(t.reminderTime),
        'isActive': t.isActive,
        'createdAt': t.createdAt.toIso8601String(),
        'lastUpdated': t.lastUpdated.toIso8601String(),
        'activeWeekdays': t.activeWeekdays,
      };

  Task _taskFromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        notes: j['notes'] as String?,
        reminderTime: _timeFromJson(j['reminderTime']),
        isActive: j['isActive'] as bool? ?? true,
        createdAt: DateTime.parse(j['createdAt'] as String),
        lastUpdated: DateTime.parse(j['lastUpdated'] as String),
        activeWeekdays: (j['activeWeekdays'] as List?)?.cast<int>(),
      );

  Map<String, dynamic> _logToJson(TaskLog l) => {
        'taskId': l.taskId,
        'date': l.date.toIso8601String(),
        'status': l.status.name,
        'completedAt': l.completedAt?.toIso8601String(),
      };

  TaskLog _logFromJson(Map<String, dynamic> j) {
    final statusName = j['status'] as String;
    final status = LogStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => throw const BackupFormatException('Unknown log status.'),
    );
    final completedAt = j['completedAt'] as String?;
    return TaskLog(
      taskId: j['taskId'] as String,
      date: DateTime.parse(j['date'] as String),
      status: status,
      completedAt: completedAt == null ? null : DateTime.parse(completedAt),
    );
  }

  Map<String, dynamic> _settingsToJson(Settings s) => {
        'notificationsEnabled': s.notificationsEnabled,
        'defaultReminderTime': _timeToJson(s.defaultReminderTime),
        'dayResetHour': s.dayResetHour,
        'followUpAfterHours': s.followUpAfterHours,
        'use24HourFormat': s.use24HourFormat,
      };

  Settings _settingsFromJson(Map<String, dynamic> j) => Settings(
        notificationsEnabled: j['notificationsEnabled'] as bool? ?? true,
        defaultReminderTime: _timeFromJson(j['defaultReminderTime']),
        dayResetHour: j['dayResetHour'] as int? ?? 0,
        followUpAfterHours: j['followUpAfterHours'] as int?,
        use24HourFormat: j['use24HourFormat'] as bool? ?? true,
      );

  /// Times are stored as "HH:mm" rather than a raw minute count so a human
  /// can read and hand-correct a backup file.
  String? _timeToJson(TimeOfDay? t) {
    if (t == null) return null;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  TimeOfDay? _timeFromJson(Object? raw) {
    if (raw == null) return null;
    final parts = (raw as String).split(':');
    if (parts.length != 2) {
      throw const BackupFormatException('Malformed time value.');
    }
    return TimeOfDay(
      hour: int.parse(parts[0]),
      minute: int.parse(parts[1]),
    );
  }
}
