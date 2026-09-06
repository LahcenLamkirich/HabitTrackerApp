import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// A single recurring daily habit/task.
///
/// Extends [HiveObject] so Hive can persist this class directly.
/// All fields are final — mutations create a new [Task] copy
/// and replace the old entry in the box.
///
/// Storage layout (kept stable for forward-compat):
///   field 0: id (String)
///   field 1: name (String)
///   field 2: icon (String?)
///   field 3: notes (String?)
///   field 4: reminderTime (TimeOfDay?)
///   field 5: isActive (bool)
///   field 6: createdAt (DateTime)
///   field 7: lastUpdated (DateTime)
class Task extends HiveObject {
  final String id;
  final String name;
  final String? icon;
  final String? notes;
  final TimeOfDay? reminderTime;
  final bool isActive;
  final DateTime createdAt;
  final DateTime lastUpdated;

  Task({
    required this.id,
    required this.name,
    this.icon,
    this.notes,
    this.reminderTime,
    this.isActive = true,
    DateTime? createdAt,
    DateTime? lastUpdated,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  Task copyWith({
    String? name,
    String? icon,
    String? notes,
    TimeOfDay? reminderTime,
    bool? isActive,
  }) {
    return Task(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      notes: notes ?? this.notes,
      reminderTime: reminderTime ?? this.reminderTime,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastUpdated: DateTime.now(),
    );
  }

  bool get hasReminder => reminderTime != null;

  String get reminderDisplay {
    if (reminderTime == null) return 'Midnight';
    return '${reminderTime!.hour.toString().padLeft(2, '0')}:${reminderTime!.minute.toString().padLeft(2, '0')}';
  }
}

/// Manual Hive adapter for [Task] (no code generation).
class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      name: fields[1] as String,
      icon: fields[2] as String?,
      notes: fields[3] as String?,
      reminderTime: fields[4] as TimeOfDay?,
      isActive: fields[5] as bool,
      createdAt: fields[6] as DateTime,
      lastUpdated: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.icon)
      ..writeByte(3)
      ..write(obj.notes)
      ..writeByte(4)
      ..write(obj.reminderTime)
      ..writeByte(5)
      ..write(obj.isActive)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.lastUpdated);
  }
}