class HistoryEvent {
  final int id;
  final String type; // 'walk', 'inactivity', 'alarm_trigger', 'alarm_dismiss'
  final DateTime timestamp;
  final int durationSeconds;
  final int steps;
  final double distance;
  final String details;

  HistoryEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.durationSeconds,
    required this.steps,
    required this.distance,
    required this.details,
  });

  factory HistoryEvent.fromMap(Map<dynamic, dynamic> map) {
    return HistoryEvent(
      id: map['id'] as int? ?? 0,
      type: map['type'] as String? ?? 'walk',
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int? ?? 0),
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      steps: map['steps'] as int? ?? 0,
      distance: (map['distance'] as num? ?? 0.0).toDouble(),
      details: map['details'] as String? ?? '',
    );
  }
}

class HourlyStep {
  final int id;
  final String dateHour; // "yyyy-MM-dd HH"
  final int steps;
  final double distance;

  HourlyStep({
    required this.id,
    required this.dateHour,
    required this.steps,
    required this.distance,
  });

  factory HourlyStep.fromMap(Map<dynamic, dynamic> map) {
    return HourlyStep(
      id: map['id'] as int? ?? 0,
      dateHour: map['date_hour'] as String? ?? '',
      steps: map['steps'] as int? ?? 0,
      distance: (map['distance'] as num? ?? 0.0).toDouble(),
    );
  }

  DateTime get dateTime {
    try {
      final parts = dateHour.split(' ');
      final dateParts = parts[0].split('-');
      final hour = int.parse(parts[1]);
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        hour,
      );
    } catch (_) {
      return DateTime.now();
    }
  }
}
