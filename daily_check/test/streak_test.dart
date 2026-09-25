// Tests for the streak and day-rollover logic.
//
// This is the arithmetic the whole app is judged on: a streak that resets a
// day early, or a habit that reads as "missed" on a day it was never
// scheduled, destroys the user's trust in every number on screen.

import 'dart:io';

import 'package:daily_check/models/models.dart';
import 'package:daily_check/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('daily_check_test');
    storage = await StorageService.init(hivePath: tempDir.path);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  /// Midnight today, the same anchor the production code uses.
  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime daysAgo(int n) => today().subtract(Duration(days: n));

  Future<Task> addDailyHabit({List<int>? weekdays}) {
    return storage.addTask(name: 'Drink water', activeWeekdays: weekdays);
  }

  group('getStreak', () {
    test('is zero for a habit that has never been done', () async {
      final task = await addDailyHabit();
      expect(storage.getStreak(task.id), 0);
    });

    test('counts consecutive completed days up to today', () async {
      final task = await addDailyHabit();
      for (var i = 0; i < 3; i++) {
        await storage.markDone(task.id, daysAgo(i));
      }
      expect(storage.getStreak(task.id), 3);
    });

    test('an unfinished today does not break a run ending yesterday',
        () async {
      // The user has not checked in yet today. Their streak should still
      // read 2, not 0 — otherwise it appears lost every morning.
      final task = await addDailyHabit();
      await storage.markDone(task.id, daysAgo(1));
      await storage.markDone(task.id, daysAgo(2));

      expect(storage.getStreak(task.id), 2);
    });

    test('stops at a genuine gap', () async {
      final task = await addDailyHabit();
      await storage.markDone(task.id, daysAgo(0));
      await storage.markDone(task.id, daysAgo(1));
      // day 2 skipped entirely
      await storage.markDone(task.id, daysAgo(3));

      expect(storage.getStreak(task.id), 2);
    });

    test('off-schedule days are stepped over, not treated as breaks',
        () async {
      // A weekdays-only habit must not lose its streak over a weekend.
      final task = await addDailyHabit(weekdays: const [1, 2, 3, 4, 5]);

      // Mark every scheduled day in the last two weeks as done.
      for (var i = 0; i < 14; i++) {
        final date = daysAgo(i);
        if (task.isScheduledOn(date)) {
          await storage.markDone(task.id, date);
        }
      }

      // Ten weekdays fall in any 14-day window.
      expect(storage.getStreak(task.id), 10);
    });

    test('a skipped day does not count towards the streak', () async {
      final task = await addDailyHabit();
      await storage.markDone(task.id, daysAgo(0));
      await storage.markSkipped(task.id, daysAgo(1));
      await storage.markDone(task.id, daysAgo(2));

      expect(storage.getStreak(task.id), 1);
    });
  });

  group('getLogicalDay', () {
    test('with a midnight reset, the logical day is the calendar day', () {
      final settings = Settings(dayResetHour: 0);
      final at2am = DateTime(2026, 1, 15, 2, 0);

      expect(storage.getLogicalDay(at2am, settings), DateTime(2026, 1, 15));
    });

    test('before the reset hour, the day is still yesterday', () {
      // A night owl with a 4am rollover who checks in at 3am is still
      // finishing the 14th, not starting the 15th.
      final settings = Settings(dayResetHour: 4);
      final at3am = DateTime(2026, 1, 15, 3, 0);

      expect(
        storage.getLogicalDay(at3am, settings),
        DateTime(2026, 1, 14, 4, 0),
      );
    });

    test('after the reset hour, the day has rolled over', () {
      final settings = Settings(dayResetHour: 4);
      final at5am = DateTime(2026, 1, 15, 5, 0);

      expect(
        storage.getLogicalDay(at5am, settings),
        DateTime(2026, 1, 15, 4, 0),
      );
    });

    test('exactly at the reset hour the new day has begun', () {
      final settings = Settings(dayResetHour: 4);
      final at4am = DateTime(2026, 1, 15, 4, 0);

      expect(
        storage.getLogicalDay(at4am, settings),
        DateTime(2026, 1, 15, 4, 0),
      );
    });

    test('rolls back across a month boundary', () {
      final settings = Settings(dayResetHour: 4);
      final justAfterMidnight = DateTime(2026, 3, 1, 1, 30);

      expect(
        storage.getLogicalDay(justAfterMidnight, settings),
        DateTime(2026, 2, 28, 4, 0),
      );
    });
  });

  group('getTaskStatus', () {
    test('reflects a stored completion', () async {
      final task = await addDailyHabit();
      await storage.markDone(task.id, today());

      expect(
        storage.getTaskStatus(task, today(), Settings()),
        TaskStatus.done,
      );
    });

    test('a day the habit is not scheduled on is never missed', () async {
      // Pick the weekday *opposite* to today so the habit is definitely
      // off-schedule, and give it a reminder time already in the past.
      final offDay = today().add(const Duration(days: 1));
      final task = await storage.addTask(
        name: 'Gym',
        activeWeekdays: [today().weekday],
        reminderTime: const TimeOfDay(hour: 0, minute: 1),
      );

      expect(
        storage.getTaskStatus(task, offDay, Settings()),
        TaskStatus.pending,
      );
    });

    test('a past reminder time today reads as missed', () async {
      final task = await storage.addTask(
        name: 'Stretch',
        reminderTime: const TimeOfDay(hour: 0, minute: 0),
      );

      // Guard: at exactly 00:00 there is no elapsed time to be late by.
      final now = DateTime.now();
      if (now.hour == 0 && now.minute == 0) return;

      expect(
        storage.getTaskStatus(task, today(), Settings()),
        TaskStatus.missed,
      );
    });
  });
}
