import 'dart:async';
import 'package:flutter/services.dart';
import '../domain/activity_state.dart';
import '../domain/history_event.dart';

class NativeService {
  static const MethodChannel _methodChannel = MethodChannel('com.viralvaghela.movenow/service');
  static const EventChannel _eventChannel = EventChannel('com.viralvaghela.movenow/updates');

  // Stream of activity updates
  Stream<ActivityState>? _updatesStream;

  Stream<ActivityState> get updatesStream {
    _updatesStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => ActivityState.fromMap(event as Map<dynamic, dynamic>));
    return _updatesStream!;
  }

  Future<bool> startService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startService');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stopService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopService');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> pauseService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('pauseService');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resumeService() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('resumeService');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> resetTimer() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('resetTimer');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> dismissAlarm() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('dismissAlarm');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSettingsSignal() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('updateSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<ActivityState> getServiceState() async {
    try {
      final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>('getServiceState');
      if (result != null) {
        return ActivityState.fromMap(result);
      }
    } catch (_) {}
    return ActivityState.initial();
  }

  Future<List<HistoryEvent>> getHistory() async {
    try {
      final result = await _methodChannel.invokeListMethod<dynamic>('getHistory');
      if (result != null) {
        return result.map((item) => HistoryEvent.fromMap(item as Map<dynamic, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<HourlyStep>> getHourlySteps() async {
    try {
      final result = await _methodChannel.invokeListMethod<dynamic>('getHourlySteps');
      if (result != null) {
        return result.map((item) => HourlyStep.fromMap(item as Map<dynamic, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> clearHistory() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('clearHistory');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> calibrateAccelerometer() async {
    try {
      final result = await _methodChannel.invokeMapMethod<dynamic, dynamic>('calibrateAccelerometer');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
    return {'success': false, 'error': 'Unknown error'};
  }
}
