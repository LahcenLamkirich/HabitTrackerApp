import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Custom Hive adapter for Flutter's [TimeOfDay] class.
///
/// TimeOfDay has two int fields: hour (0-23) and minute (0-59).
/// Stored compactly as two single bytes for portability.
class TimeOfDayAdapter extends TypeAdapter<TimeOfDay> {
  @override
  final int typeId = 2;

  @override
  TimeOfDay read(BinaryReader reader) {
    final hour = reader.readByte();
    final minute = reader.readByte();
    return TimeOfDay(hour: hour, minute: minute);
  }

  @override
  void write(BinaryWriter writer, TimeOfDay obj) {
    writer.writeByte(obj.hour);
    writer.writeByte(obj.minute);
  }
}