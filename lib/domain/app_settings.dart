import 'package:flutter/material.dart';

class AppSettings {
  final int inactivityTimeoutMinutes;
  final double requiredDistanceMeters;
  final String alarmSoundPath;
  final int alarmVolume;
  final int vibratePatternIndex;
  final bool quietHoursEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final String units;
  final String themeMode;
  final int accentColorIndex;
  final double weightKg;
  final double heightCm;
  final double stepLengthMeters;
  final int dailyWaterGoalMl;
  final int currentWaterMl;

  AppSettings({
    required this.inactivityTimeoutMinutes,
    required this.requiredDistanceMeters,
    required this.alarmSoundPath,
    required this.alarmVolume,
    required this.vibratePatternIndex,
    required this.quietHoursEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.units,
    required this.themeMode,
    required this.accentColorIndex,
    required this.weightKg,
    required this.heightCm,
    required this.stepLengthMeters,
    required this.dailyWaterGoalMl,
    required this.currentWaterMl,
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      inactivityTimeoutMinutes: 60,
      requiredDistanceMeters: 100.0,
      alarmSoundPath: '',
      alarmVolume: 100,
      vibratePatternIndex: 0,
      quietHoursEnabled: false,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
      units: 'meters',
      themeMode: 'system',
      accentColorIndex: 0,
      weightKg: 70.0,
      heightCm: 175.0,
      stepLengthMeters: 0.762,
      dailyWaterGoalMl: 2000,
      currentWaterMl: 0,
    );
  }

  AppSettings copyWith({
    int? inactivityTimeoutMinutes,
    double? requiredDistanceMeters,
    String? alarmSoundPath,
    int? alarmVolume,
    int? vibratePatternIndex,
    bool? quietHoursEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    String? units,
    String? themeMode,
    int? accentColorIndex,
    double? weightKg,
    double? heightCm,
    double? stepLengthMeters,
    int? dailyWaterGoalMl,
    int? currentWaterMl,
  }) {
    return AppSettings(
      inactivityTimeoutMinutes: inactivityTimeoutMinutes ?? this.inactivityTimeoutMinutes,
      requiredDistanceMeters: requiredDistanceMeters ?? this.requiredDistanceMeters,
      alarmSoundPath: alarmSoundPath ?? this.alarmSoundPath,
      alarmVolume: alarmVolume ?? this.alarmVolume,
      vibratePatternIndex: vibratePatternIndex ?? this.vibratePatternIndex,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      units: units ?? this.units,
      themeMode: themeMode ?? this.themeMode,
      accentColorIndex: accentColorIndex ?? this.accentColorIndex,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      stepLengthMeters: stepLengthMeters ?? this.stepLengthMeters,
      dailyWaterGoalMl: dailyWaterGoalMl ?? this.dailyWaterGoalMl,
      currentWaterMl: currentWaterMl ?? this.currentWaterMl,
    );
  }

  // Get color seed based on index
  Color get accentColor {
    final List<Color> colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
    ];
    if (accentColorIndex >= 0 && accentColorIndex < colors.length) {
      return colors[accentColorIndex];
    }
    return colors[0];
  }

  ThemeMode get systemThemeMode {
    switch (themeMode) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
