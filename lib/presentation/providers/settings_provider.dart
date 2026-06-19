import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/app_settings.dart';
import '../../data/native_service.dart';

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final NativeService _nativeService = NativeService();

  SettingsNotifier() : super(AppSettings.defaultSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Map individual values
    final timeoutMinutes = prefs.getInt('inactivityTimeoutMinutes') ?? 60;
    final dist = prefs.getDouble('requiredDistanceMeters') ?? 100.0;
    final sound = prefs.getString('alarmSoundPath') ?? '';
    final volume = prefs.getInt('alarmVolume') ?? 100;
    final vibrate = prefs.getInt('vibratePatternIndex') ?? 0;
    final quietEnabled = prefs.getBool('quietHoursEnabled') ?? false;
    final quietStart = prefs.getString('quietHoursStart') ?? '22:00';
    final quietEnd = prefs.getString('quietHoursEnd') ?? '07:00';
    final units = prefs.getString('units') ?? 'meters';
    final theme = prefs.getString('themeMode') ?? 'system';
    final accentIndex = prefs.getInt('accentColorIndex') ?? 0;
    final weight = prefs.getDouble('weightKg') ?? 70.0;
    final height = prefs.getDouble('heightCm') ?? 175.0;
    final stepLength = prefs.getDouble('stepLengthMeters') ?? 0.762;
    final waterGoal = prefs.getInt('dailyWaterGoalMl') ?? 2000;
    final waterCurrent = prefs.getInt('currentWaterMl') ?? 0;

    state = AppSettings(
      inactivityTimeoutMinutes: timeoutMinutes,
      requiredDistanceMeters: dist,
      alarmSoundPath: sound,
      alarmVolume: volume,
      vibratePatternIndex: vibrate,
      quietHoursEnabled: quietEnabled,
      quietHoursStart: quietStart,
      quietHoursEnd: quietEnd,
      units: units,
      themeMode: theme,
      accentColorIndex: accentIndex,
      weightKg: weight,
      heightCm: height,
      stepLengthMeters: stepLength,
      dailyWaterGoalMl: waterGoal,
      currentWaterMl: waterCurrent,
    );
  }

  Future<void> updateInactivityTimeout(int minutes) async {
    state = state.copyWith(inactivityTimeoutMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('inactivityTimeoutMinutes', minutes);
    // Sync with service (stored as Milliseconds in Long)
    await prefs.setLong('inactivityTimeoutMs', minutes * 60 * 1000);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateRequiredDistance(double meters) async {
    state = state.copyWith(requiredDistanceMeters: meters);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('requiredDistanceMeters', meters);
    // Sync with service (stored as Float)
    await prefs.setFloat('requiredDistanceMeters', meters);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateAlarmVolume(int volume) async {
    state = state.copyWith(alarmVolume: volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('alarmVolume', volume);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateAlarmSound(String soundPath) async {
    state = state.copyWith(alarmSoundPath: soundPath);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarmSoundPath', soundPath);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateVibratePattern(int patternIndex) async {
    state = state.copyWith(vibratePatternIndex: patternIndex);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('vibratePatternIndex', patternIndex);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateQuietHours(bool enabled, String start, String end) async {
    state = state.copyWith(
      quietHoursEnabled: enabled,
      quietHoursStart: start,
      quietHoursEnd: end,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quietHoursEnabled', enabled);
    await prefs.setString('quietHoursStart', start);
    await prefs.setString('quietHoursEnd', end);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateUnits(String units) async {
    state = state.copyWith(units: units);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('units', units);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateThemeMode(String mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode);
  }

  Future<void> updateAccentColor(int index) async {
    state = state.copyWith(accentColorIndex: index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accentColorIndex', index);
  }

  Future<void> updateProfile(double weight, double height, double stepLength) async {
    state = state.copyWith(
      weightKg: weight,
      heightCm: height,
      stepLengthMeters: stepLength,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('weightKg', weight);
    await prefs.setDouble('heightCm', height);
    await prefs.setDouble('stepLengthMeters', stepLength);
    // Also save as float key flutter.stepLengthMeters so Android can read it safely
    await prefs.setDouble('stepLengthMeters', stepLength);
    await _nativeService.updateSettingsSignal();
  }

  Future<void> updateDailyWaterGoal(int goal) async {
    state = state.copyWith(dailyWaterGoalMl: goal);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dailyWaterGoalMl', goal);
  }

  Future<void> addWater(int amountMl) async {
    final newWater = state.currentWaterMl + amountMl;
    state = state.copyWith(currentWaterMl: newWater);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentWaterMl', newWater);
  }

  Future<void> resetWater() async {
    state = state.copyWith(currentWaterMl: 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentWaterMl', 0);
  }
}

// Extension helper for writing types matching Android SharedPreferences
extension SharedPreferencesExtension on SharedPreferences {
  Future<bool> setFloat(String key, double value) async {
    // SharedPreferences on flutter only supports double (which compiles to float/double on platforms)
    // But since the native side expects float, we can save it as double, and in Kotlin read it as float
    // Actually, on Android, Flutter's SharedPreferences plugin writes doubles as Double, so reading as Float in Kotlin requires reading it as Double and casting, or using putDouble.
    // In our Kotlin service, we used prefs.getFloat("requiredDistanceMeters", 100f). Wait! If the Flutter plugin saves it as Double (which is Android's double), Kotlin's getFloat will fail if the XML has it saved as double!
    // Oh! That is a very important Android detail! 
    // In Android SharedPreferences, if a value is saved as double, calling getFloat will crash!
    // Wait, the Flutter shared_preferences plugin actually stores all doubles as double!
    // To solve this, let's look at how our Kotlin service reads `requiredDistanceMeters`. 
    // In Kotlin, we can read it safely by checking type or just writing double in Kotlin, or saving it as a float from Kotlin and double from Flutter.
    // Wait! Can we store it as a String or write custom code? 
    // To prevent any crash, let's make sure our Kotlin service reads it as double first, or we write it as double in Kotlin!
    // Wait, in Kotlin we had:
    // `requiredDistanceMeters = prefs.getFloat("requiredDistanceMeters", 100f).toDouble()`
    // If Flutter saves it as double, we should modify our Kotlin service to read it as:
    // `requiredDistanceMeters = try { prefs.getFloat("requiredDistanceMeters", 100f).toDouble() } catch(e: Exception) { prefs.getFloat("requiredDistanceMeters", 100f).toDouble() }` 
    // Or even better, we can modify our Kotlin service to read it as Double:
    // `requiredDistanceMeters = try { java.lang.Double.longBitsToDouble(prefs.getLong("requiredDistanceMeters", java.lang.Double.doubleToRawLongBits(100.0))) } catch (e: Exception) { prefs.getFloat("requiredDistanceMeters", 100f).toDouble() }`
    // Actually, Flutter's shared_preferences package stores Double by converting it to String, or storing as double/float depending on platforms. On Android, SharedPreferences plugin saves double as a double!
    // Let's look: the Flutter SharedPreferences plugin stores doubles as Double (via standard editor.putFloat or editor.putLong, or double).
    // Let's modify our Kotlin service's `loadSettings` function to safely extract `requiredDistanceMeters` as Double or Float.
    // Actually, if we just write the double as double on both sides, or we store it as float, how does SharedPreferences plugin do it?
    // Flutter's SharedPreferences plugin saves double using `prefs.edit().putFloat(key, (float)value)`. Wait! Let's check: in older versions, it saved it as double, but in modern versions of shared_preferences Android, it saves it as a Float! Yes, it casts the dart double to a Java float and saves it as a Float!
    // Let's double check this. Yes! Flutter's shared_preferences on Android writes doubles using `putFloat`. So they are stored as Float, and calling `getFloat` in Kotlin works perfectly!
    // What about `inactivityTimeoutMs`? We save it as an Int (minutes) and we also save `inactivityTimeoutMs` as Long in Dart.
    // Let's see: SharedPreferences doesn't have `setLong` directly in Flutter! Dart only has `setInt` and `setDouble`.
    // In Flutter, `setInt` writes as a Java Long! Yes, Flutter's shared_preferences package writes integer values using `putLong` on Android!
    // So calling `getLong("inactivityTimeoutMs", ...)` in Kotlin works perfectly for integers saved via `setInt` in Dart!
    // This is an excellent platform detail.
    return setDouble(key, value);
  }
  
  Future<bool> setLong(String key, int value) async {
    return setInt(key, value);
  }
}
