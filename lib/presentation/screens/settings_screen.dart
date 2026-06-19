import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/settings_provider.dart';
import '../../domain/app_settings.dart';
import '../../data/native_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _activityPermission = false;
  bool _notificationPermission = false;
  bool _batteryOptimizationExempt = false;
  bool _isCalibrating = false;
  String? _calibrationResult;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final activity = await Permission.activityRecognition.status.isGranted;
    final notification = await Permission.notification.status.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    setState(() {
      _activityPermission = activity;
      _notificationPermission = notification;
      _batteryOptimizationExempt = battery;
    });
  }

  Future<void> _requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    setState(() {
      _activityPermission = status.isGranted;
    });
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationPermission = status.isGranted;
    });
  }

  Future<void> _requestBatteryExemption() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _batteryOptimizationExempt = status.isGranted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings & Customization",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: theme.brightness == Brightness.dark
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                // Permissions Card
                _buildSectionHeader(context, "Permissions"),
                _buildPermissionsCard(context),
                const SizedBox(height: 16),
                _buildBypassGuideCard(context),
                const SizedBox(height: 24),

                // Inactivity Tracking Section
                _buildSectionHeader(context, "Activity Tracking"),
                _buildTrackingCard(context, settings, settingsNotifier),
                const SizedBox(height: 16),
                _buildCalibrationCard(context),
                const SizedBox(height: 24),

                // Alarms & Vibration
                _buildSectionHeader(context, "Alarm & Alert Settings"),
                _buildAlarmCard(context, settings, settingsNotifier),
                const SizedBox(height: 24),

                // Personal Health Profile
                _buildSectionHeader(context, "Personal Health Profile"),
                _buildPersonalProfileCard(context, settings, settingsNotifier),
                const SizedBox(height: 24),

                // Personalization
                _buildSectionHeader(context, "App Design"),
                _buildThemeCard(context, settings, settingsNotifier),
                const SizedBox(height: 24),

                // Quiet Hours
                _buildSectionHeader(context, "Quiet Hours"),
                _buildQuietHoursCard(context, settings, settingsNotifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPermissionsCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          _buildPermissionTile(
            context: context,
            title: "Activity Recognition",
            subtitle: "Required to detect steps and activity status",
            isGranted: _activityPermission,
            onPressed: _requestActivityPermission,
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildPermissionTile(
            context: context,
            title: "Notifications",
            subtitle: "Required to show persistent countdown and alarms",
            isGranted: _notificationPermission,
            onPressed: _requestNotificationPermission,
          ),
          const Divider(height: 24, color: Colors.white10),
          _buildPermissionTile(
            context: context,
            title: "Battery Optimization Exemption",
            subtitle: "Recommended to avoid service being killed",
            isGranted: _batteryOptimizationExempt,
            onPressed: _requestBatteryExemption,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isGranted ? const Color(0xFF10B981).withOpacity(0.12) : theme.colorScheme.primary,
            foregroundColor: isGranted ? const Color(0xFF10B981) : Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isGranted ? null : onPressed,
          child: Text(
            isGranted ? "Granted" : "Grant",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingCard(BuildContext context, var settings, var notifier) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          // Timer Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Inactivity Threshold", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                "${settings.inactivityTimeoutMinutes} min",
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: settings.inactivityTimeoutMinutes.toDouble().clamp(1, 240),
            min: 1,
            max: 240,
            divisions: 239,
            label: "${settings.inactivityTimeoutMinutes} min",
            onChanged: (val) {
              notifier.updateInactivityTimeout(val.toInt());
            },
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [1, 30, 45, 60].map((minutes) {
              final isSelected = settings.inactivityTimeoutMinutes == minutes;
              return ChoiceChip(
                label: Text("$minutes min"),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    notifier.updateInactivityTimeout(minutes);
                  }
                },
                selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                checkmarkColor: theme.colorScheme.primary,
                labelStyle: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : theme.textTheme.bodyMedium?.color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 11,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Distance Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Required Walk Distance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                settings.units == 'km'
                    ? "${(settings.requiredDistanceMeters / 1000).toStringAsFixed(2)} km"
                    : "${settings.requiredDistanceMeters.toInt()} meters",
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: settings.requiredDistanceMeters,
            min: 50,
            max: 1000,
            divisions: 19,
            label: "${settings.requiredDistanceMeters.toInt()}m",
            onChanged: (val) {
              notifier.updateRequiredDistance(val);
            },
          ),
          const SizedBox(height: 16),

          // Units Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Measurement Units", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'meters', label: Text('Meters', style: TextStyle(fontSize: 11))),
                  ButtonSegment<String>(value: 'km', label: Text('KM', style: TextStyle(fontSize: 11))),
                ],
                selected: {settings.units},
                onSelectionChanged: (newSelection) {
                  notifier.updateUnits(newSelection.first);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(BuildContext context, var settings, var notifier) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          // Volume Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Alarm Volume", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                "${settings.alarmVolume}%",
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          Slider(
            value: settings.alarmVolume.toDouble(),
            min: 0,
            max: 100,
            divisions: 10,
            onChanged: (val) {
              notifier.updateAlarmVolume(val.toInt());
            },
          ),
          const SizedBox(height: 16),

          // Vibration patterns
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Vibration Style", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              DropdownButton<int>(
                value: settings.vibratePatternIndex,
                underline: const SizedBox(),
                borderRadius: BorderRadius.circular(12),
                items: const [
                  DropdownMenuItem(value: 0, child: Text("Continuous Standard", style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 1, child: Text("Heartbeat Pattern", style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 2, child: Text("Fast Alerts", style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) notifier.updateVibratePattern(val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, var settings, var notifier) {
    final theme = Theme.of(context);
    final accentColors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFFEC4899), // Pink
      const Color(0xFF8B5CF6), // Purple
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("App Theme", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(value: 'system', icon: Icon(Icons.brightness_auto, size: 16), label: Text('Auto', style: TextStyle(fontSize: 10))),
                  ButtonSegment<String>(value: 'light', icon: Icon(Icons.light_mode, size: 16), label: Text('Light', style: TextStyle(fontSize: 10))),
                  ButtonSegment<String>(value: 'dark', icon: Icon(Icons.dark_mode, size: 16), label: Text('Dark', style: TextStyle(fontSize: 10))),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (newSelection) {
                  notifier.updateThemeMode(newSelection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Accent Theme Color", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(
                _getPresetName(settings.accentColorIndex),
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: accentColors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, idx) {
                final color = accentColors[idx];
                final isSelected = settings.accentColorIndex == idx;
                return GestureDetector(
                  onTap: () => notifier.updateAccentColor(idx),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getPresetName(int index) {
    switch (index) {
      case 0: return "Default Indigo";
      case 1: return "Emerald Forest";
      case 2: return "Amber Sunset";
      case 3: return "Crimson Ruby";
      case 4: return "Cyberpunk Neon";
      case 5: return "Amethyst Star";
      default: return "Default Indigo";
    }
  }

  Widget _buildQuietHoursCard(BuildContext context, var settings, var notifier) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Enable Quiet Hours", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Switch(
                value: settings.quietHoursEnabled,
                onChanged: (val) {
                  notifier.updateQuietHours(val, settings.quietHoursStart, settings.quietHoursEnd);
                },
              ),
            ],
          ),
          if (settings.quietHoursEnabled) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Start Hours", style: TextStyle(fontSize: 12)),
                TextButton(
                  onPressed: () => _selectTime(context, settings.quietHoursStart, (newTime) {
                    notifier.updateQuietHours(true, newTime, settings.quietHoursEnd);
                  }),
                  child: Text(settings.quietHoursStart, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("End Hours", style: TextStyle(fontSize: 12)),
                TextButton(
                  onPressed: () => _selectTime(context, settings.quietHoursEnd, (newTime) {
                    notifier.updateQuietHours(true, settings.quietHoursStart, newTime);
                  }),
                  child: Text(settings.quietHoursEnd, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, String currentTime, ValueChanged<String> onSelect) async {
    final parts = currentTime.split(":");
    final initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    
    final selected = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selected != null) {
      final formatted = "${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}";
      onSelect(formatted);
    }
  }

  Widget _buildBypassGuideCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_update_warning_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                "Background Reliability Guide",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Custom Android skins (OnePlus/Oppo ColorOS, Samsung OneUI, Xiaomi HyperOS) aggressively terminate background trackers. Follow these two quick steps to ensure 100% service uptime:",
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          _buildGuideStep(
            number: "1",
            title: "Lock App in Recent Apps",
            desc: "Open your Recent Apps screen, long press or tap the options menu above the MoveNow preview, and select 'Lock'. This prevents Android from force-closing the app.",
          ),
          const SizedBox(height: 12),
          _buildGuideStep(
            number: "2",
            title: "Allow Unrestricted Background Activity",
            desc: "Enable 'Battery Exemption' above so Android doesn't put the tracking service to sleep during long periods of sitting.",
          ),
        ],
      ),
    );
  }

  Widget _buildGuideStep({required String number, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(fontSize: 10, color: Colors.grey, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCalibrationCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Sensor Auto-Calibration",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Tune step detection sensitivity based on your device's unique accelerometer noise floor. Lay your device flat on a stable surface before beginning.",
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          if (_isCalibrating)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Text(
                  "Calibrating noise floor... Keep phone still.",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            )
          else ...[
            if (_calibrationResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                  ),
                ),
                child: Text(
                  _calibrationResult!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _startCalibration,
                icon: const Icon(Icons.flash_on_rounded, size: 16),
                label: const Text(
                  "Start Calibration",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _startCalibration() async {
    setState(() {
      _isCalibrating = true;
      _calibrationResult = null;
    });

    final ns = NativeService();
    final res = await ns.calibrateAccelerometer();

    if (mounted) {
      setState(() {
        _isCalibrating = false;
        if (res['success'] == true) {
          final double noiseFloor = res['noiseFloor'] ?? 0.0;
          final double threshold = res['newThreshold'] ?? 0.0;
          _calibrationResult = "Calibration complete!\nNoise Floor: ${noiseFloor.toStringAsFixed(3)} m/s²\nCustom Threshold: ${threshold.toStringAsFixed(2)} m/s²";
        } else {
          _calibrationResult = "Calibration failed: ${res['error'] ?? 'Unknown error'}";
        }
      });
    }
  }

  Widget _buildPersonalProfileCard(BuildContext context, AppSettings settings, SettingsNotifier settingsNotifier) {
    final theme = Theme.of(context);
    final weight = settings.weightKg;
    final height = settings.heightCm;
    final stepLength = settings.stepLengthMeters;
    final waterGoal = settings.dailyWaterGoalMl;

    final heightM = height / 100.0;
    final bmi = heightM > 0 ? weight / (heightM * heightM) : 0.0;

    String bmiStatus = "Unknown";
    Color bmiColor = Colors.grey;
    if (bmi > 0) {
      if (bmi < 18.5) {
        bmiStatus = "Underweight";
        bmiColor = Colors.blue;
      } else if (bmi < 25.0) {
        bmiStatus = "Normal";
        bmiColor = Colors.green;
      } else if (bmi < 30.0) {
        bmiStatus = "Overweight";
        bmiColor = Colors.orange;
      } else {
        bmiStatus = "Obese";
        bmiColor = Colors.red;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.health_and_safety_rounded, color: Color(0xFF10B981), size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Health Statistics",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _showProfileEditorBottomSheet(context, settings, settingsNotifier),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_rounded, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      const Text(
                        "Edit Profile",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Circular/Rounded Badge for BMI
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      bmiColor.withOpacity(0.15),
                      bmiColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: bmiColor.withOpacity(0.3), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "BMI",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bmi.toStringAsFixed(1),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.titleLarge?.color),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: bmiColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bmiStatus,
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: bmiColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Profile stats display
              Expanded(
                child: Column(
                  children: [
                    _buildStatRow("Weight", "${weight.toStringAsFixed(1)} kg", Icons.monitor_weight_outlined),
                    const SizedBox(height: 8),
                    _buildStatRow("Height", "${height.toInt()} cm", Icons.height_rounded),
                    const SizedBox(height: 8),
                    _buildStatRow("Step Length", "${stepLength.toStringAsFixed(3)} m", Icons.directions_walk_rounded),
                    const SizedBox(height: 8),
                    _buildStatRow("Water Goal", "${waterGoal} ml", Icons.water_drop_outlined),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showProfileEditorBottomSheet(
    BuildContext context,
    AppSettings settings,
    SettingsNotifier settingsNotifier,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileEditorBottomSheet(
        settings: settings,
        settingsNotifier: settingsNotifier,
      ),
    );
  }
}

class _ProfileEditorBottomSheet extends StatefulWidget {
  final AppSettings settings;
  final SettingsNotifier settingsNotifier;

  const _ProfileEditorBottomSheet({
    required this.settings,
    required this.settingsNotifier,
  });

  @override
  State<_ProfileEditorBottomSheet> createState() => _ProfileEditorBottomSheetState();
}

class _ProfileEditorBottomSheetState extends State<_ProfileEditorBottomSheet> {
  late double _weight;
  late double _height;
  late double _stepLength;
  late int _waterGoal;
  bool _isHeightInCm = true;

  String _cmToFtIn(double cm) {
    double totalInches = cm / 2.54;
    int feet = (totalInches / 12).floor();
    int inches = (totalInches % 12).round();
    if (inches == 12) {
      feet += 1;
      inches = 0;
    }
    return "$feet'$inches\"";
  }

  @override
  void initState() {
    super.initState();
    _weight = widget.settings.weightKg;
    _height = widget.settings.heightCm;
    _stepLength = widget.settings.stepLengthMeters;
    _waterGoal = widget.settings.dailyWaterGoalMl;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Live BMI calculation
    final heightM = _height / 100.0;
    final bmi = heightM > 0 ? _weight / (heightM * heightM) : 0.0;

    String bmiStatus = "Unknown";
    Color bmiColor = Colors.grey;
    if (bmi > 0) {
      if (bmi < 18.5) {
        bmiStatus = "Underweight";
        bmiColor = Colors.blue;
      } else if (bmi < 25.0) {
        bmiStatus = "Normal";
        bmiColor = Colors.green;
      } else if (bmi < 30.0) {
        bmiStatus = "Overweight";
        bmiColor = Colors.orange;
      } else {
        bmiStatus = "Obese";
        bmiColor = Colors.red;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Personal Profile Settings",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Adjust your physical parameters to compute precise active calories, custom walking distances, and water reminders.",
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 20),
            
            // Dynamic BMI Preview Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    bmiColor.withOpacity(0.12),
                    bmiColor.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bmiColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.health_and_safety_rounded, color: bmiColor, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Calculated BMI Index",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            bmi.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: bmiColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bmiStatus,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: bmiColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Weight Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Weight", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("${_weight.toStringAsFixed(1)} kg", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ],
            ),
            Slider(
              value: _weight,
              min: 30.0,
              max: 150.0,
              divisions: 1200,
              onChanged: (val) {
                setState(() {
                  _weight = val;
                });
              },
            ),
            
            // Height Section with Dual Unit Selector (cm and ft)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Height", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isHeightInCm = !_isHeightInCm;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "cm",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isHeightInCm ? theme.colorScheme.primary : Colors.grey,
                          ),
                        ),
                        const Text(" | ", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          "ft",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isHeightInCm ? theme.colorScheme.primary : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _isHeightInCm
                      ? "${_height.toInt()} cm (${_cmToFtIn(_height)})"
                      : "${_cmToFtIn(_height)} (${_height.toInt()} cm)",
                  style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ],
            ),
            Slider(
              value: _isHeightInCm
                  ? _height
                  : (_height / 2.54).clamp(39.0, 86.0),
              min: _isHeightInCm ? 100.0 : 39.0,
              max: _isHeightInCm ? 220.0 : 86.0,
              divisions: _isHeightInCm ? 120 : 47,
              onChanged: (val) {
                setState(() {
                  if (_isHeightInCm) {
                    _height = val;
                  } else {
                    _height = val * 2.54;
                  }
                });
              },
            ),
            
            // Step Length Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Step Length", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("${_stepLength.toStringAsFixed(3)} m", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ],
            ),
            Slider(
              value: _stepLength,
              min: 0.3,
              max: 1.5,
              divisions: 120,
              onChanged: (val) {
                setState(() {
                  _stepLength = val;
                });
              },
            ),
            
            // Water Goal Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Daily Water Goal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text("${_waterGoal} ml", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ],
            ),
            Slider(
              value: _waterGoal.toDouble(),
              min: 1000.0,
              max: 5000.0,
              divisions: 16,
              onChanged: (val) {
                setState(() {
                  _waterGoal = val.toInt();
                });
              },
            ),
            
            const SizedBox(height: 28),
            
            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  await widget.settingsNotifier.updateProfile(_weight, _height, _stepLength);
                  await widget.settingsNotifier.updateDailyWaterGoal(_waterGoal);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Profile settings updated successfully!"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text(
                  "Save Profile Changes",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
