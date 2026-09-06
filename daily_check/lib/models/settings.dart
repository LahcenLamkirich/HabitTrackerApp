import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// User settings for the Daily Check app.
///
/// Stored as a singleton at a known key ('settings') in the settings box.
/// Only one instance is ever created.
class Settings extends HiveObject {
  /// Global toggle for all notifications.
  final bool notificationsEnabled;

  /// Default reminder time for new tasks. The user can override this
  /// per-task on the add/edit screen.
  final TimeOfDay? defaultReminderTime;

  /// The hour at which the "day" resets (0-23, default 0 = midnight).
  /// Some users prefer a different rollover time (e.g. 4am for night owls).
  final int dayResetHour;

  /// Optional: hours after which to send a follow-up reminder for an
  /// undone task. Null disables follow-ups.
  final int? followUpAfterHours;

  /// Whether the app uses 24-hour time format (read from system, but cached
  /// for the UI to react to settings changes without rebuilding the world).
  final bool use24HourFormat;

  Settings({
    this.notificationsEnabled = true,
    this.defaultReminderTime,
    this.dayResetHour = 0,
    this.followUpAfterHours,
    this.use24HourFormat = true,
  });

  Settings copyWith({
    bool? notificationsEnabled,
    TimeOfDay? defaultReminderTime,
    int? dayResetHour,
    int? followUpAfterHours,
    bool clearDefaultReminder = false,
    bool clearFollowUp = false,
    bool? use24HourFormat,
  }) {
    return Settings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      defaultReminderTime: clearDefaultReminder
          ? null
          : (defaultReminderTime ?? this.defaultReminderTime),
      dayResetHour: dayResetHour ?? this.dayResetHour,
      followUpAfterHours:
          clearFollowUp ? null : (followUpAfterHours ?? this.followUpAfterHours),
      use24HourFormat: use24HourFormat ?? this.use24HourFormat,
    );
  }

  /// The TimeOfDay at which the day rolls over to a new date.
  TimeOfDay get dayResetTime {
    return TimeOfDay(hour: dayResetHour, minute: 0);
  }
}

/// Manual Hive adapter for [Settings] (no code generation).
class SettingsAdapter extends TypeAdapter<Settings> {
  @override
  final int typeId = 4;

  @override
  Settings read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Settings(
      notificationsEnabled: (fields[0] as bool?) ?? true,
      defaultReminderTime: fields[1] as TimeOfDay?,
      dayResetHour: (fields[2] as int?) ?? 0,
      followUpAfterHours: fields[3] as int?,
      use24HourFormat: (fields[4] as bool?) ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, Settings obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.notificationsEnabled)
      ..writeByte(1)
      ..write(obj.defaultReminderTime)
      ..writeByte(2)
      ..write(obj.dayResetHour)
      ..writeByte(3)
      ..write(obj.followUpAfterHours)
      ..writeByte(4)
      ..write(obj.use24HourFormat);
  }
}