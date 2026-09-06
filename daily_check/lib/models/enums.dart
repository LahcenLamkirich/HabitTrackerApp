import 'package:hive/hive.dart';

/// Top-level enums used across the Daily Check app.

/// The state of a task for a specific day.
enum TaskStatus {
  pending, // not yet done, not past reminder time
  done, // marked complete
  missed, // past reminder time and still unchecked
  skipped, // user explicitly chose to skip today
}

/// The outcome of a task on a given day, as stored in history.
enum LogStatus {
  done,
  missed,
  skipped,
}

/// Manual Hive adapter for [LogStatus].
class LogStatusAdapter extends TypeAdapter<LogStatus> {
  @override
  final int typeId = 3;

  @override
  LogStatus read(BinaryReader reader) {
    return LogStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, LogStatus obj) {
    writer.writeByte(obj.index);
  }
}