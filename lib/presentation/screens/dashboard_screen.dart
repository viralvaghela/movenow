import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/activity_state.dart';
import '../providers/service_provider.dart';
import '../providers/settings_provider.dart';
import '../../domain/app_settings.dart';
import '../providers/history_provider.dart';
import '../widgets/progress_ring.dart';
import '../widgets/confetti_canvas.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _lastAlarmActive = false;
  double _lastWalkProgress = 0.0;
  int _confettiTriggerCount = 0;
  int _insightIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Initialize initial values
    final initialState = ref.read(serviceStateProvider);
    final settingsInit = ref.read(settingsProvider);
    _lastAlarmActive = initialState.isAlarmActive;
    _lastWalkProgress = initialState.distanceProgress(settingsInit.stepLengthMeters);

    // Refresh history to calculate real-time streak on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(historyProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(serviceStateProvider);
    final settings = ref.watch(settingsProvider);
    final historyState = ref.watch(historyProvider);
    final theme = Theme.of(context);

    // Control pulse animation based on alarm state
    if (state.isAlarmActive) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
    }

    // Calculate formatting
    final remainingSec = state.remainingSeconds;
    final remainingMin = (remainingSec / 60).ceil();
    final timeProgress = state.timeProgress;
    final walkProgress = state.distanceProgress(settings.stepLengthMeters);

    // Trigger confetti if alarm resolved or walk goal achieved
    if ((_lastAlarmActive && !state.isAlarmActive) || (_lastWalkProgress < 1.0 && walkProgress >= 1.0)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _confettiTriggerCount++;
          });
        }
      });
    }
    _lastAlarmActive = state.isAlarmActive;
    _lastWalkProgress = walkProgress;

    final String countdownText = state.isAlarmActive
        ? "ALARM!"
        : state.isPaused
            ? "Paused"
            : "$remainingMin min";

    final String subtitleText = state.isAlarmActive
        ? "Walk 100m to stop"
        : "${(state.currentPeriodSteps * settings.stepLengthMeters).toInt()} / ${settings.requiredDistanceMeters.toInt()}m";

    // Personalized Calories estimate: MET-based formula using weight (kg) and actual step length (meters)
    final double distanceMiles = (state.stepsToday * settings.stepLengthMeters) / 1609.34;
    final double weightLbs = settings.weightKg * 2.20462;
    final double caloriesBurnt = state.stepsToday > 0 ? (distanceMiles * weightLbs * 0.57) : 0.0;
    
    // Format distance today
    final String distanceTodayText = settings.units == 'km'
        ? "${(state.distanceToday / 1000).toStringAsFixed(2)} km"
        : "${state.distanceToday.toInt()} m";

    return Scaffold(
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 100), // padding bottom to avoid floating navbar
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Bar / Header
                  _buildHeader(context, state, historyState.streakCount),
                  const SizedBox(height: 24),

                  // Main Circular Ring & Activity State
                  if (state.isAlarmActive)
                    _buildAlarmAlert(context)
                  else
                    _buildTrackerCard(context, state, timeProgress, walkProgress, countdownText, subtitleText),
                  const SizedBox(height: 24),

                  // Status Indicator Badge
                  _buildActivityStatusBadge(context, state),
                  const SizedBox(height: 24),

                  // Stats Grid (Today's performance)
                  _buildStatsGrid(context, state, distanceTodayText, caloriesBurnt),
                  const SizedBox(height: 24),

                  // Quick Action Controls
                  _buildControlPanel(context, state),
                  const SizedBox(height: 24),

                  // Water Intake Companion
                  _buildWaterIntakeCard(context, settings),
                  const SizedBox(height: 24),

                  // Quick Stretch Card
                  _buildQuickStretchCard(context),
                  const SizedBox(height: 20),

                  // Daily Health Insight Card
                  _buildDailyInsightCard(context),
                ],
              ),
            ),
          ),
          ConfettiCanvas(triggerCount: _confettiTriggerCount),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ActivityState state, int streakCount) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MoveNow",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              state.isPaused ? "Monitoring paused" : "Keep moving for active health",
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
              ),
            ),
          ],
        ),
        // Streak Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 4),
              Text(
                streakCount == 0 ? "Start Streak" : "$streakCount Day Streak",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackerCard(
    BuildContext context,
    ActivityState state,
    double timeProgress,
    double walkProgress,
    String centerText,
    String subtitleText,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        children: [
          ProgressRing(
            timeProgress: timeProgress,
            walkProgress: walkProgress,
            centerText: centerText,
            subtitleText: subtitleText,
            isAlarmActive: false,
          ),
          const SizedBox(height: 16),
          Text(
            state.isPaused
                ? "Monitoring Suspended"
                : "Active period starts in ${formatDuration(state.inactivityTimeout - DateTime.now().difference(state.lastWalkTime))}",
            style: TextStyle(
              fontSize: 12,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmAlert(BuildContext context) {
    final theme = Theme.of(context);
    return ScaleTransition(
      scale: Tween(begin: 0.96, end: 1.02).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
            const SizedBox(height: 16),
            Text(
              "INACTIVITY WARNING",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You have been sitting too long! Get up and walk 100 meters immediately to dismiss the alarm, or click below.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red[800],
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () {
                ref.read(serviceStateProvider.notifier).dismissAlarm();
              },
              child: const Text(
                "DISMISS ALARM",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityStatusBadge(BuildContext context, ActivityState state) {
    final theme = Theme.of(context);
    final String activity = state.currentActivity;

    Color badgeColor;
    IconData icon;
    String label;

    switch (activity) {
      case "WALKING":
        badgeColor = const Color(0xFF10B981);
        icon = Icons.directions_walk_rounded;
        label = "Walking detected";
        break;
      case "RUNNING":
        badgeColor = Colors.cyan;
        icon = Icons.directions_run_rounded;
        label = "Running detected";
        break;
      case "STANDING":
        badgeColor = Colors.blue;
        icon = Icons.accessibility_new_rounded;
        label = "Standing detected";
        break;
      case "PAUSED":
        badgeColor = Colors.orange;
        icon = Icons.pause_circle_filled_rounded;
        label = "Monitoring paused";
        break;
      default:
        badgeColor = Colors.blueGrey;
        icon = Icons.airline_seat_recline_normal_rounded;
        label = "Sitting / Still";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: badgeColor, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, ActivityState state, String distanceStr, double calories) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _buildStatCard(
          context: context,
          icon: Icons.directions_walk_rounded,
          iconColor: Colors.purple,
          label: "Steps Today",
          value: "${state.stepsToday}",
        ),
        _buildStatCard(
          context: context,
          icon: Icons.map_outlined,
          iconColor: Colors.blue,
          label: "Distance",
          value: distanceStr,
        ),
        _buildStatCard(
          context: context,
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.red,
          label: "Calories",
          value: "${calories.toInt()} kcal",
        ),
        _buildStatCard(
          context: context,
          icon: Icons.timer_outlined,
          iconColor: Colors.teal,
          label: "Status",
          value: state.isPaused ? "Paused" : "Active",
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildControlPanel(BuildContext context, ActivityState state) {
    final theme = Theme.of(context);
    final serviceNotifier = ref.read(serviceStateProvider.notifier);

    // If service is disabled at boot/system level
    if (!state.serviceEnabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            const Icon(Icons.notifications_off_outlined, size: 40),
            const SizedBox(height: 12),
            const Text(
              "Background Tracker Disabled",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              "Enable MoveNow to start monitoring sitting duration and preventing prolonged inactivity.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                serviceNotifier.startService();
              },
              child: const Text("Start Tracker"),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Pause / Resume Button
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: state.isPaused ? theme.colorScheme.primary : theme.colorScheme.error.withOpacity(0.12),
              foregroundColor: state.isPaused ? Colors.white : theme.colorScheme.error,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: state.isPaused
                    ? BorderSide.none
                    : BorderSide(color: theme.colorScheme.error.withOpacity(0.2)),
              ),
            ),
            onPressed: () {
              if (state.isPaused) {
                serviceNotifier.resumeService();
              } else {
                serviceNotifier.pauseService();
              }
            },
            icon: Icon(state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
            label: Text(
              state.isPaused ? "Resume Monitoring" : "Pause Tracking",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Reset Button
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withOpacity(0.12)
                    : Colors.black.withOpacity(0.12),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () {
              serviceNotifier.resetTimer();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              "Reset",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  String formatDuration(Duration duration) {
    if (duration.isNegative) return "00:00";
    final min = duration.inMinutes.toString().padLeft(2, '0');
    final sec = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$min:$sec";
  }

  Widget _buildQuickStretchCard(BuildContext context) {
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
              Icon(Icons.accessibility_new_rounded, color: theme.colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              const Text(
                "Desk Stretch Breaks",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Relieve muscle tension and reverse vascular compression from sitting with a quick 4-step stretch routine.",
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
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
              onPressed: () => _showStretchBottomSheet(context),
              icon: const Icon(Icons.play_circle_filled_rounded, size: 18),
              label: const Text(
                "Start Stretch Break",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStretchBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _DeskStretchSheet(),
    );
  }

  Widget _buildDailyInsightCard(BuildContext context) {
    final theme = Theme.of(context);
    final insights = [
      "Fatty liver disease (NAFLD) is directly linked to prolonged sitting. Walking 2 mins every hour helps your body process lipids.",
      "Every hour you sit reduces blood flow by up to 50%. A quick stand-up breaks the vascular compression in your lower body.",
      "Breaking up sitting time improves insulin sensitivity, helping your muscles absorb glucose and lowering diabetes risk.",
      "Physical movement triggers endorphin release, boosting focus and clearing mental fatigue from desk work.",
      "Stretching your neck and shoulders regularly prevents chronic tension headaches and posture misalignment.",
      "Continuous standing and walking increases caloric expenditure by 3x compared to sitting.",
    ];

    return InkWell(
      onTap: () {
        setState(() {
          _insightIndex = (_insightIndex + 1) % insights.length;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.12),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tips_and_updates_rounded, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daily Health Insight",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    insights[_insightIndex],
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tap card to cycle tips • Learn & Prevent",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterIntakeCard(BuildContext context, AppSettings settings) {
    return _WaterIntakeCompanion(settings: settings, ref: ref);
  }
}

class _DeskStretchSheet extends StatefulWidget {
  const _DeskStretchSheet();

  @override
  State<_DeskStretchSheet> createState() => _DeskStretchSheetState();
}

class _DeskStretchSheetState extends State<_DeskStretchSheet> {
  int _currentStep = 0;
  int _secondsLeft = 15;
  Timer? _timer;
  bool _isPlaying = true;

  final List<Map<String, String>> _stretches = [
    {
      'title': 'Neck Tilt Release',
      'desc': 'Slowly tilt your head to the side, letting your ear reach toward your shoulder. Hold, breathe, then swap sides.',
      'duration': '15',
    },
    {
      'title': 'Shoulder Roll Opener',
      'desc': 'Roll your shoulders backward in slow, giant circles. Open up your chest and keep your neck relaxed.',
      'duration': '15',
    },
    {
      'title': 'Seated Torso Twist',
      'desc': 'Place your right hand on your left knee and gently rotate your upper body to the left. Hold, then repeat on the right side.',
      'duration': '15',
    },
    {
      'title': 'Standing Quad Stretch',
      'desc': 'Stand up, hold onto a chair for balance. Pull your left heel toward your glutes, feeling the stretch in your thighs. Swap sides.',
      'duration': '15',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_isPlaying) {
        setState(() {
          if (_secondsLeft > 0) {
            _secondsLeft--;
          } else {
            // Next stretch
            if (_currentStep < _stretches.length - 1) {
              _currentStep++;
              _secondsLeft = int.parse(_stretches[_currentStep]['duration']!);
            } else {
              _timer?.cancel();
              Navigator.pop(context);
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _stretches[_currentStep];
    final maxSec = double.parse(step['duration']!);
    final progress = _secondsLeft / maxSec;

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            "Desk Stretch Break",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step['title']!,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            step['desc']!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 32),
          
          // Timer Widget
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$_secondsLeft",
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "seconds left",
                    style: TextStyle(fontSize: 10, color: Colors.grey.withOpacity(0.8)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Step dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_stretches.length, (idx) {
              final active = _currentStep == idx;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? theme.colorScheme.primary : Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),
          
          // Action Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 28),
                onPressed: _currentStep > 0
                    ? () {
                        setState(() {
                          _currentStep--;
                          _secondsLeft = int.parse(_stretches[_currentStep]['duration']!);
                        });
                      }
                    : null,
              ),
              FloatingActionButton(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: () {
                  setState(() {
                    _isPlaying = !_isPlaying;
                  });
                },
                child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 28),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 28),
                onPressed: () {
                  setState(() {
                    if (_currentStep < _stretches.length - 1) {
                      _currentStep++;
                      _secondsLeft = int.parse(_stretches[_currentStep]['duration']!);
                    } else {
                      _timer?.cancel();
                      Navigator.pop(context);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

}

class _WaterIntakeCompanion extends StatefulWidget {
  final AppSettings settings;
  final WidgetRef ref;

  const _WaterIntakeCompanion({required this.settings, required this.ref});

  @override
  State<_WaterIntakeCompanion> createState() => _WaterIntakeCompanionState();
}

class _WaterIntakeCompanionState extends State<_WaterIntakeCompanion> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVal = widget.settings.currentWaterMl;
    final goalVal = widget.settings.dailyWaterGoalMl;
    final progress = (currentVal / goalVal).clamp(0.0, 1.0);

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
                  Icon(Icons.water_drop_rounded, color: Colors.blue[400], size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    "Water Intake Tracker",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.grey),
                onPressed: () => widget.ref.read(settingsProvider.notifier).resetWater(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Animated Water Jar/Cup
              Container(
                width: 70,
                height: 90,
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20), top: Radius.circular(6)),
                  border: Border.all(
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.1),
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18), top: Radius.circular(4)),
                  child: AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _WaterWavePainter(
                          progress: progress,
                          waveValue: _waveController.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Logs and actions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$currentVal / $goalVal ml",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      progress >= 1.0
                          ? "Daily goal reached! Keep it up!"
                          : "${((1.0 - progress) * goalVal).toInt()} ml remaining today",
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[400],
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => widget.ref.read(settingsProvider.notifier).addWater(250),
                            child: const Text("+ 250ml", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              side: BorderSide(color: Colors.blue[200]!),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => widget.ref.read(settingsProvider.notifier).addWater(500),
                            child: Text("+ 500ml", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[400])),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaterWavePainter extends CustomPainter {
  final double progress;
  final double waveValue;

  _WaterWavePainter({required this.progress, required this.waveValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue[400]!.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final path = Path();
    final yOffset = size.height * (1.0 - progress);

    if (progress <= 0.0) return;

    path.moveTo(0, yOffset);
    
    // Draw continuous wave
    for (double x = 0; x <= size.width; x++) {
      final waveHeight = size.height * 0.06;
      final angle = (x / size.width * 2 * 3.1415926) + (waveValue * 2 * 3.1415926);
      final y = yOffset + waveHeight * progress * (1.0 - progress) * 1.5 * sin(angle);
      path.lineTo(x, y.clamp(0.0, size.height));
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Draw second wave with different phase
    final paint2 = Paint()
      ..color = Colors.blue[300]!.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, yOffset);
    for (double x = 0; x <= size.width; x++) {
      final waveHeight = size.height * 0.05;
      final angle = (x / size.width * 2 * 3.1415926) + (waveValue * 2 * 3.1415926) + 3.1415926; // 180 degrees phase shift
      final y = yOffset + waveHeight * progress * (1.0 - progress) * 1.2 * sin(angle);
      path2.lineTo(x, y.clamp(0.0, size.height));
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _WaterWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.waveValue != waveValue;
  }
}
