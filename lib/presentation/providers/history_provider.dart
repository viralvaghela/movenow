import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/history_event.dart';
import '../../data/native_service.dart';

class HistoryState {
  final List<HistoryEvent> events;
  final List<HourlyStep> hourlySteps;
  final bool isLoading;

  HistoryState({
    required this.events,
    required this.hourlySteps,
    required this.isLoading,
  });

  factory HistoryState.initial() {
    return HistoryState(events: [], hourlySteps: [], isLoading: false);
  }

  HistoryState copyWith({
    List<HistoryEvent>? events,
    List<HourlyStep>? hourlySteps,
    bool? isLoading,
  }) {
    return HistoryState(
      events: events ?? this.events,
      hourlySteps: hourlySteps ?? this.hourlySteps,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get streakCount {
    if (hourlySteps.isEmpty) {
      return 0;
    }

    // Extract all unique dates where steps > 0
    final Map<String, int> dailySteps = {};
    for (var step in hourlySteps) {
      final dateStr = step.dateHour.split(' ')[0]; // yyyy-MM-dd
      dailySteps[dateStr] = (dailySteps[dateStr] ?? 0) + step.steps;
    }

    final activeDates = dailySteps.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toSet();

    if (activeDates.isEmpty) {
      return 0;
    }

    final today = DateTime.now();
    final todayStr = _formatDate(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayStr = _formatDate(yesterday);

    // Determine starting date for streak verification
    String startStr;
    if (activeDates.contains(todayStr)) {
      startStr = todayStr;
    } else if (activeDates.contains(yesterdayStr)) {
      startStr = yesterdayStr;
    } else {
      return 0;
    }

    int streak = 0;
    DateTime checkDate = startStr == todayStr ? today : yesterday;

    while (true) {
      final checkStr = _formatDate(checkDate);
      if (activeDates.contains(checkStr)) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  bool get isChairDodger {
    final Map<String, int> dailyDisruptions = {};
    for (var event in events) {
      if (event.type == 'alarm_dismiss' || event.type == 'walk') {
        final dateStr = _formatDate(event.timestamp);
        dailyDisruptions[dateStr] = (dailyDisruptions[dateStr] ?? 0) + 1;
      }
    }
    return dailyDisruptions.values.any((count) => count >= 5);
  }

  bool get isActiveLegend {
    return streakCount >= 14;
  }

  bool get isNightOwl {
    for (var event in events) {
      if (event.type == 'alarm_dismiss') {
        final hour = event.timestamp.hour;
        if (hour >= 20 || hour < 4) {
          return true;
        }
      }
    }
    return false;
  }

  String get inactivityHotspotText {
    final Map<String, int> hotspots = {};
    final daysOfWeek = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
    
    for (var event in events) {
      if (event.type == 'alarm_trigger') {
        final dt = event.timestamp;
        final dayName = daysOfWeek[dt.weekday % 7];
        final key = "$dayName ${dt.hour}";
        hotspots[key] = (hotspots[key] ?? 0) + 1;
      }
    }

    if (hotspots.isEmpty) {
      return "No inactivity hotspots detected yet. Keep tracking to generate scheduled stretch break insights!";
    }

    var maxKey = "";
    var maxCount = 0;
    hotspots.forEach((key, count) {
      if (count > maxCount) {
        maxCount = count;
        maxKey = key;
      }
    });

    final parts = maxKey.split(' ');
    final day = parts[0];
    final hr = int.parse(parts[1]);
    
    final startHour12 = hr == 0 ? "12 AM" : hr > 12 ? "${hr - 12} PM" : hr == 12 ? "12 PM" : "$hr AM";
    final endHour = hr + 1;
    final endHour12 = endHour == 24 ? "12 AM" : endHour > 12 ? "${endHour - 12} PM" : endHour == 12 ? "12 PM" : "$endHour AM";

    return "You sit the most on ${day}s between $startHour12 and $endHour12. We recommend a scheduled stretch break.";
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return "$y-$m-$d";
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<HistoryState> {
  final NativeService _nativeService = NativeService();

  HistoryNotifier() : super(HistoryState.initial()) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final eventsList = await _nativeService.getHistory();
      final hourlyList = await _nativeService.getHourlySteps();
      state = HistoryState(
        events: eventsList,
        hourlySteps: hourlyList,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> clearHistory() async {
    state = state.copyWith(isLoading: true);
    await _nativeService.clearHistory();
    state = HistoryState(events: [], hourlySteps: [], isLoading: false);
  }
}
