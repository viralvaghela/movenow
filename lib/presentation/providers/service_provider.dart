import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/activity_state.dart';
import '../../data/native_service.dart';

final serviceStateProvider = StateNotifierProvider<ServiceProvider, ActivityState>((ref) {
  return ServiceProvider();
});

class ServiceProvider extends StateNotifier<ActivityState> {
  final NativeService _nativeService = NativeService();
  StreamSubscription<ActivityState>? _subscription;

  ServiceProvider() : super(ActivityState.initial()) {
    _init();
  }

  Future<void> _init() async {
    // Load current state immediately
    final initialState = await _nativeService.getServiceState();
    state = initialState;

    // Listen to updates from foreground service
    _subscription = _nativeService.updatesStream.listen(
      (update) {
        state = update;
      },
      onError: (err) {
        // Handle stream errors
      },
    );
  }

  Future<void> startService() async {
    await _nativeService.startService();
    // Recheck state
    final currentState = await _nativeService.getServiceState();
    state = currentState;
  }

  Future<void> stopService() async {
    await _nativeService.stopService();
    // Reset to inactive state
    state = ActivityState.initial().copyWith(serviceEnabled: false);
  }

  Future<void> pauseService() async {
    await _nativeService.pauseService();
  }

  Future<void> resumeService() async {
    await _nativeService.resumeService();
  }

  Future<void> resetTimer() async {
    await _nativeService.resetTimer();
  }

  Future<void> dismissAlarm() async {
    await _nativeService.dismissAlarm();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// Simple extension to copy and alter ActivityState
extension ActivityStateExtension on ActivityState {
  ActivityState copyWith({
    bool? isPaused,
    DateTime? lastWalkTime,
    int? currentPeriodSteps,
    int? stepsToday,
    double? distanceToday,
    String? currentActivity,
    bool? isAlarmActive,
    Duration? inactivityTimeout,
    double? requiredDistanceMeters,
    bool? serviceEnabled,
  }) {
    return ActivityState(
      isPaused: isPaused ?? this.isPaused,
      lastWalkTime: lastWalkTime ?? this.lastWalkTime,
      currentPeriodSteps: currentPeriodSteps ?? this.currentPeriodSteps,
      stepsToday: stepsToday ?? this.stepsToday,
      distanceToday: distanceToday ?? this.distanceToday,
      currentActivity: currentActivity ?? this.currentActivity,
      isAlarmActive: isAlarmActive ?? this.isAlarmActive,
      inactivityTimeout: inactivityTimeout ?? this.inactivityTimeout,
      requiredDistanceMeters: requiredDistanceMeters ?? this.requiredDistanceMeters,
      serviceEnabled: serviceEnabled ?? this.serviceEnabled,
    );
  }
}
