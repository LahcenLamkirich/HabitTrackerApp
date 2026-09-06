import 'package:flutter/material.dart';

/// Maps task icon names (strings stored in Hive) to Material icons.
/// Add new entries here as users request new icons.
class IconHelper {
  static const Map<String, IconData> _map = {
    'supplements': Icons.medication_outlined,
    'water': Icons.water_drop_outlined,
    'fitness': Icons.fitness_center,
    'medication': Icons.medication,
    'food': Icons.restaurant,
    'sleep': Icons.bedtime_outlined,
    'reading': Icons.menu_book,
    'workout': Icons.sports_gymnastics,
    'meditation': Icons.self_improvement,
    'default': Icons.task_alt,
  };

  static IconData fromName(String? name) {
    if (name == null) return _map['default']!;
    return _map[name] ?? _map['default']!;
  }

  static List<String> get allNames => _map.keys.where((k) => k != 'default').toList();
}
