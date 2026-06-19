class ActivityState {
  final bool isPaused;
  final DateTime lastWalkTime;
  final int currentPeriodSteps;
  final int stepsToday;
  final double distanceToday;
  final String currentActivity;
  final bool isAlarmActive;
  final Duration inactivityTimeout;
  final double requiredDistanceMeters;
  final bool serviceEnabled;

  ActivityState({
    required this.isPaused,
    required this.lastWalkTime,
    required this.currentPeriodSteps,
    required this.stepsToday,
    required this.distanceToday,
    required this.currentActivity,
    required this.isAlarmActive,
    required this.inactivityTimeout,
    required this.requiredDistanceMeters,
    required this.serviceEnabled,
  });

  factory ActivityState.initial() {
    return ActivityState(
      isPaused: false,
      lastWalkTime: DateTime.now(),
      currentPeriodSteps: 0,
      stepsToday: 0,
      distanceToday: 0.0,
      currentActivity: 'STILL',
      isAlarmActive: false,
      inactivityTimeout: const Duration(hours: 1),
      requiredDistanceMeters: 100.0,
      serviceEnabled: true,
    );
  }

  factory ActivityState.fromMap(Map<dynamic, dynamic> map) {
    return ActivityState(
      isPaused: map['isPaused'] as bool? ?? false,
      lastWalkTime: DateTime.fromMillisecondsSinceEpoch(
        map['lastWalkTime'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      currentPeriodSteps: map['currentPeriodSteps'] as int? ?? 0,
      stepsToday: map['stepsToday'] as int? ?? 0,
      distanceToday: (map['distanceToday'] as num? ?? 0.0).toDouble(),
      currentActivity: map['currentActivity'] as String? ?? 'STILL',
      isAlarmActive: map['isAlarmActive'] as bool? ?? false,
      inactivityTimeout: Duration(milliseconds: map['inactivityTimeoutMs'] as int? ?? 3600000),
      requiredDistanceMeters: (map['requiredDistanceMeters'] as num? ?? 100.0).toDouble(),
      serviceEnabled: map['serviceEnabled'] as bool? ?? true,
    );
  }

  int get remainingSeconds {
    if (isPaused) return inactivityTimeout.inSeconds;
    final elapsed = DateTime.now().difference(lastWalkTime);
    final remaining = inactivityTimeout - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  double distanceProgress(double stepLength) {
    if (isPaused) return 0.0;
    final currentDistance = currentPeriodSteps * stepLength;
    final progress = currentDistance / requiredDistanceMeters;
    return progress > 1.0 ? 1.0 : progress;
  }

  double get timeProgress {
    if (isPaused) return 0.0;
    if (inactivityTimeout.inSeconds == 0) return 0.0;
    final elapsed = DateTime.now().difference(lastWalkTime).inSeconds;
    final progress = elapsed / inactivityTimeout.inSeconds;
    return progress > 1.0 ? 1.0 : progress;
  }
}
