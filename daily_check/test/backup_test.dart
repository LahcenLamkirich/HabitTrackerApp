// Tests for backup export / restore.
//
// A backup is the user's only protection against losing their whole history,
// so the round trip has to be lossless, and a bad file must be rejected
// *before* anything is overwritten.

import 'dart:io';

import 'package:daily_check/models/models.dart';
import 'package:daily_check/services/backup_service.dart';
import 'package:daily_check/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;
  late BackupService backup;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daily_check_backup_test');
    storage = await StorageService.init(hivePath: tempDir.path);
    backup = BackupService(storage);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  group('round trip', () {
    test('preserves habits, their fields, and their history', () async {
      final task = await storage.addTask(
        name: 'Stretch',
        notes: '5-10 minutes',
        icon: 'fitness',
        reminderTime: const TimeOfDay(hour: 7, minute: 30),
        activeWeekdays: const [1, 3, 5],
      );
      await storage.markDone(task.id, today());
      await storage.markSkipped(
          task.id, today().subtract(const Duration(days: 1)));

      final json = backup.encodeBackup();

      // Wipe everything, then restore from the file.
      await storage.replaceAll(tasks: [], logs: []);
      expect(storage.allTasks, isEmpty);

      final result = await backup.importFromJson(json);

      expect(result.tasks, 1);
      expect(result.logs, 2);

      final restored = storage.allTasks.single;
      expect(restored.id, task.id);
      expect(restored.name, 'Stretch');
      expect(restored.notes, '5-10 minutes');
      expect(restored.icon, 'fitness');
      expect(restored.reminderTime, const TimeOfDay(hour: 7, minute: 30));
      expect(restored.activeWeekdays, const [1, 3, 5]);
      expect(restored.createdAt, task.createdAt);

      // History must come back addressable by the same keys as before.
      expect(storage.getLog(task.id, today())?.status, LogStatus.done);
      expect(storage.getStreak(task.id), greaterThanOrEqualTo(0));
    });

    test('preserves settings', () async {
      await storage.saveSettings(Settings(
        notificationsEnabled: false,
        defaultReminderTime: const TimeOfDay(hour: 21, minute: 15),
        dayResetHour: 4,
        followUpAfterHours: 3,
        use24HourFormat: false,
      ));

      final json = backup.encodeBackup();
      await storage.saveSettings(Settings());

      await backup.importFromJson(json);

      final s = storage.settings;
      expect(s.notificationsEnabled, isFalse);
      expect(s.defaultReminderTime, const TimeOfDay(hour: 21, minute: 15));
      expect(s.dayResetHour, 4);
      expect(s.followUpAfterHours, 3);
      expect(s.use24HourFormat, isFalse);
    });

    test('replaces rather than merges', () async {
      final kept = await storage.addTask(name: 'Read');
      final json = backup.encodeBackup();

      // A habit added after the export must not survive the restore.
      await storage.addTask(name: 'Added later');
      expect(storage.allTasks, hasLength(2));

      await backup.importFromJson(json);

      expect(storage.allTasks, hasLength(1));
      expect(storage.allTasks.single.id, kept.id);
    });

    test('an empty app exports and restores cleanly', () async {
      final json = backup.encodeBackup();
      final result = await backup.importFromJson(json);

      expect(result.tasks, 0);
      expect(result.logs, 0);
      expect(storage.allTasks, isEmpty);
    });
  });

  group('rejects bad input without destroying data', () {
    /// Every case here must leave the existing habit untouched.
    Future<void> expectRefused(String source) async {
      final before = storage.allTasks.map((t) => t.id).toList();

      await expectLater(
        backup.importFromJson(source),
        throwsA(isA<BackupFormatException>()),
      );

      expect(storage.allTasks.map((t) => t.id).toList(), before);
    }

    setUp(() async {
      await storage.addTask(name: 'Existing habit');
    });

    test('not JSON at all', () async {
      await expectRefused('this is not json');
    });

    test('JSON, but not a backup', () async {
      await expectRefused('{"hello":"world"}');
    });

    test('a JSON array rather than an object', () async {
      await expectRefused('[1,2,3]');
    });

    test('a backup from a newer schema version', () async {
      await expectRefused(
        '{"format":"daily_check_backup","schemaVersion":999,'
        '"tasks":[],"logs":[]}',
      );
    });

    test('a task record missing its required fields', () async {
      await expectRefused(
        '{"format":"daily_check_backup","schemaVersion":1,'
        '"tasks":[{"name":"No id here"}],"logs":[]}',
      );
    });

    test('a malformed reminder time', () async {
      await expectRefused(
        '{"format":"daily_check_backup","schemaVersion":1,"tasks":['
        '{"id":"a","name":"X","createdAt":"2026-01-01T00:00:00.000",'
        '"lastUpdated":"2026-01-01T00:00:00.000","reminderTime":"7am"}'
        '],"logs":[]}',
      );
    });

    test('an unknown log status', () async {
      await expectRefused(
        '{"format":"daily_check_backup","schemaVersion":1,"tasks":[],'
        '"logs":[{"taskId":"a","date":"2026-01-01T00:00:00.000",'
        '"status":"exploded"}]}',
      );
    });
  });

  group('file naming', () {
    test('is sortable and dated', () {
      expect(
        backup.suggestedFileName(DateTime(2026, 9, 5)),
        'daily-check-backup-2026-09-05.json',
      );
    });
  });
}
