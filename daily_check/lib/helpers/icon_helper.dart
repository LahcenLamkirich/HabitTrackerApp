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
    'walk': Icons.directions_walk,
    'bike': Icons.directions_bike,
    'swim': Icons.pool,
    'yoga': Icons.spa_outlined,
    'writing': Icons.edit_note,
    'coding': Icons.code_rounded,
    'music': Icons.music_note_outlined,
    'art': Icons.palette_outlined,
    'study': Icons.school_outlined,
    'finance': Icons.savings_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'coffee': Icons.local_cafe_outlined,
    'nature': Icons.park_outlined,
    'pet': Icons.pets_outlined,
    'gratitude': Icons.favorite_outline,
    'language': Icons.translate_rounded,
    'social': Icons.people_outline_rounded,
    'phone_free': Icons.phonelink_off_outlined,
    'sun': Icons.wb_sunny_outlined,
    'default': Icons.task_alt,
  };

  static IconData fromName(String? name) {
    if (name == null) return _map['default']!;
    return _map[name] ?? _map['default']!;
  }

  static List<String> get allNames => _map.keys.where((k) => k != 'default').toList();

  /// Accent palette cycled by icon position, so every habit gets a distinct
  /// color — consistent wherever a habit's icon is shown (New/Edit Habit
  /// form, the Today checklist, etc.) — that scales automatically as icons
  /// are added above without needing a color assigned to each one by hand.
  static const List<Color> _accentPalette = [
    Color(0xFFE85D30),
    Color(0xFF3A86FF),
    Color(0xFF00B4D8),
    Color(0xFFEF476F),
    Color(0xFFB388FF),
    Color(0xFFFFB703),
    Color(0xFF6C63FF),
    Color(0xFF2EC4B6),
    Color(0xFFFF6B6B),
    Color(0xFF52B788),
    Color(0xFF118AB2),
    Color(0xFFEF7B45),
    Color(0xFF9D4EDD),
    Color(0xFF06D6A0),
    Color(0xFFF4A261),
  ];

  static Color colorFor(String? name) {
    if (name == null) return _accentPalette[0];
    final index = allNames.indexOf(name);
    if (index < 0) return _accentPalette[0];
    return _accentPalette[(index + 1) % _accentPalette.length];
  }
}
