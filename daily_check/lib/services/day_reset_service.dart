import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Watches the system clock and fires [onDayReset] when the local day rolls
/// over. Also re-evaluates "missed" status for active tasks and re-schedules
/// any pending notifications.
///
/// The day-reset logic is the trickiest part of a daily-checklist app. The
/// core idea is:
///
///   * Each task has a "done for today" state. When the day changes,
///     all tasks become pending again.
///   * "Day change" is defined by [Settings.dayResetHour] (default midnight).
///   * We poll the wall clock every minute (cheap; only checks a DateTime)
///     and call [onDayReset] the first time we observe a new logical day.
///   * On app start, we check if the stored "last known day" is stale, and
///     if so, also fire [onDayReset].
///
/// This means the app catches up correctly even if it's been killed for
/// days, as long as it has access to the system clock.
class DayResetService {
  Timer? _timer;
  DateTime? _lastKnownDay;
  final StorageService _storage;
  final NotificationService _notifications;

  /// Called whenever the day rolls over (or on catch-up after a long pause).
  /// Use this to re-schedule notifications, refresh UI state, etc.
  VoidCallback? onDayReset;

  /// Called every minute to let the UI re-evaluate "missed" status
  /// (since a task can become "missed" without the day changing).
  VoidCallback? onTick;

  DayResetService({
    required StorageService storage,
    required NotificationService notifications,
  })  : _storage = storage,
        _notifications = notifications;

  /// Start watching the clock. Idempotent.
  void start() {
    if (_timer != null) return;
    // Run once immediately to catch up after a kill/relaunch.
    _check();
    // Then poll every 60 seconds. We use 1 minute because the smallest
    // meaningful event is a minute boundary (a new day, or a task that
    // just became missed).
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  /// Stop watching the clock.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Force a re-evaluation. Used when the user changes settings like the
  /// day-reset hour, or returns to the app from background.
  void forceCheck() => _check();

  Future<void> _check() async {
    final settings = _storage.settings;
    final now = DateTime.now();
    final currentDay = _storage.getLogicalDay(now, settings);

    final dayChanged = _lastKnownDay == null ||
        !_isSameDay(_lastKnownDay!, currentDay);

    if (dayChanged) {
      _lastKnownDay = currentDay;
      // Re-schedule notifications for all active tasks. The notification
      // service is idempotent so this is safe.
      await _notifications.rescheduleAll(
        _storage.activeTasks,
        settings: settings,
      );
      onDayReset?.call();
    } else {
      // Same day — just re-tick to allow the UI to mark newly-missed tasks.
      onTick?.call();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}