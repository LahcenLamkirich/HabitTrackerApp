import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'enums.dart';

/// A log entry recording whether a task was completed / missed / skipped
/// on a given date.
///
/// Storage layout (kept stable for forward-compat):
///   field 0: taskId (String)
///   field 1: date (DateTime)
///   field 2: status (LogStatus)
///   field 3: completedAt (DateTime?)
class TaskLog extends HiveObject {
  final String taskId;
  final DateTime date;
  final LogStatus status;
  final DateTime? completedAt;

  TaskLog({
    required this.taskId,
    required this.date,
    required this.status,
    this.completedAt,
  });

  /// Convenience factory for marking a task as done.
  factory TaskLog.done({required String taskId, required DateTime date}) {
    return TaskLog(
      taskId: taskId,
      date: date,
      status: LogStatus.done,
      completedAt: DateTime.now(),
    );
  }

  factory TaskLog.missed({required String taskId, required DateTime date}) {
    return TaskLog(
      taskId: taskId,
      date: date,
      status: LogStatus.missed,
    );
  }

  factory TaskLog.skipped({required String taskId, required DateTime date}) {
    return TaskLog(
      taskId: taskId,
      date: date,
      status: LogStatus.skipped,
    );
  }

  /// Convert to [TaskStatus] for UI display.
  TaskStatus toTaskStatus() {
    return switch (status) {
      LogStatus.done => TaskStatus.done,
      LogStatus.missed => TaskStatus.missed,
      LogStatus.skipped => TaskStatus.skipped,
    };
  }

  String get description {
    switch (status) {
      case LogStatus.done:
        if (completedAt != null) {
          return 'Completed ${DateFormat.jm().format(completedAt!)}';
        }
        return 'Completed';
      case LogStatus.missed:
        return 'Missed';
      case LogStatus.skipped:
        return 'Skipped';
    }
  }

  String get shortLabel {
    return switch (status) {
      LogStatus.done => '✓',
      LogStatus.missed => '✗',
      LogStatus.skipped => '–',
    };
  }
}

/// Manual Hive adapter for [TaskLog] (no code generation).
class TaskLogAdapter extends TypeAdapter<TaskLog> {
  @override
  final int typeId = 1;

  @override
  TaskLog read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return TaskLog(
      taskId: fields[0] as String,
      date: fields[1] as DateTime,
      status: fields[2] as LogStatus,
      completedAt: fields[3] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskLog obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.taskId)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.status)
      ..writeByte(3)
      ..write(obj.completedAt);
  }
}