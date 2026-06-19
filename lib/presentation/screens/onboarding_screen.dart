import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Permission states
  bool _activityGranted = false;
  bool _notificationsGranted = false;
  bool _batteryExempt = false;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    final activity = await Permission.activityRecognition.isGranted;
    final notifications = await Permission.notification.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _activityGranted = activity;
        _notificationsGranted = notifications;
        _batteryExempt = battery;
      });
    }
  }

  Future<void> _requestActivity() async {
    final status = await Permission.activityRecognition.request();
    setState(() {
      _activityGranted = status.isGranted;
    });
  }

  Future<void> _requestNotifications() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationsGranted = status.isGranted;
    });
  }

  Future<void> _requestBattery() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    setState(() {
      _batteryExempt = status.isGranted;
    });
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F172A), const Color(0xFF020617)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Page Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildWelcomePage(theme, isDark),
                      _buildFattyLiverPage(theme, isDark),
                      _buildHelpfulPage(theme, isDark),
                      _buildPermissionsPage(theme, isDark),
                    ],
                  ),
                ),

                // Footer Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(4, (index) {
                          final isSelected = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: isSelected ? 24 : 8,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      
                      // Action Button
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: theme.colorScheme.primary.withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          if (_currentPage < 3) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOutCubic,
                            );
                          } else {
                            _finishOnboarding();
                          }
                        },
                        child: Text(
                          _currentPage == 3 ? "Let's Go!" : "Next",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomePage(ThemeData theme, bool isDark) {
    return _buildPageLayout(
      graphic: _PulseWarningGraphic(isDark: isDark),
      title: "The Danger of Prolonged Sitting",
      description: "Modern life keeps us desk-bound, but human bodies are built to move. Sitting for hours drops your metabolic rate, reduces circulation, and raises the risk of cardiac disease, diabetes, and muscle atrophy.",
      tag: "THE SEDENTARY THREAT",
      tagColor: Colors.redAccent,
    );
  }

  Widget _buildFattyLiverPage(ThemeData theme, bool isDark) {
    return _buildPageLayout(
      graphic: _LiverGraphic(isDark: isDark),
      title: "NAFLD & Silent Health Risks",
      description: "Sitting for prolonged periods has been directly linked to Non-Alcoholic Fatty Liver Disease (NAFLD). Without regular muscle contractions, lipids accumulate inside your liver, paving the way for chronic inflammation.",
      tag: "SILENT ORGAN DAMAGE",
      tagColor: Colors.orangeAccent,
    );
  }

  Widget _buildHelpfulPage(ThemeData theme, bool isDark) {
    return _buildPageLayout(
      graphic: _TrackerRingGraphic(isDark: isDark, accentColor: theme.colorScheme.primary),
      title: "MoveNow Keeps You Active",
      description: "We monitor your inactivity levels continuously in the background. If you sit still for too long, a high-priority alarm sounds. The only way to silence it is to get up and walk 100 meters!",
      tag: "THE ACTIVE REMEDY",
      tagColor: const Color(0xFF10B981),
    );
  }

  Widget _buildPermissionsPage(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.security_rounded, size: 56, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            "Enable Tracking Services",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "To monitor steps in the background and raise alarms, MoveNow needs these standard Android permissions. Grant them below to start.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 32),
          
          // Activity Permission Row
          _buildPermissionOption(
            title: "Activity Recognition",
            desc: "Required to accurately count steps & activity.",
            granted: _activityGranted,
            onTap: _requestActivity,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          // Notifications Row
          _buildPermissionOption(
            title: "Push Notifications",
            desc: "Required to display alarms & timers in background.",
            granted: _notificationsGranted,
            onTap: _requestNotifications,
            theme: theme,
          ),
          const SizedBox(height: 12),
          
          // Battery Exemption Row
          _buildPermissionOption(
            title: "Battery Exemption",
            desc: "Prevents Android from killing the tracking service.",
            granted: _batteryExempt,
            onTap: _requestBattery,
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionOption({
    required String title,
    required String desc,
    required bool granted,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E293B).withOpacity(0.4)
            : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: granted
              ? const Color(0xFF10B981).withOpacity(0.2)
              : theme.colorScheme.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: granted ? const Color(0xFF10B981) : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: granted ? null : onTap,
            child: Text(
              granted ? "Granted" : "Grant",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageLayout({
    required Widget graphic,
    required String title,
    required String description,
    required String tag,
    required Color tagColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Center(child: graphic),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: tagColor,
                fontWeight: FontWeight.bold,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),
          const Spacer(flex: 1),
        ],
      ),
    );
  }
}

// ---------------- GRAPHICS WIDGETS ----------------

class _PulseWarningGraphic extends StatefulWidget {
  final bool isDark;
  const _PulseWarningGraphic({required this.isDark});

  @override
  State<_PulseWarningGraphic> createState() => _PulseWarningGraphicState();
}

class _PulseWarningGraphicState extends State<_PulseWarningGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _PulseWarningPainter(
            progress: _controller.value,
            isDark: widget.isDark,
          ),
        );
      },
    );
  }
}

class _PulseWarningPainter extends CustomPainter {
  final double progress;
  final bool isDark;
  _PulseWarningPainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.stroke;

    // Background circle
    paint.color = Colors.red.withOpacity(0.05);
    paint.strokeWidth = 2;
    canvas.drawCircle(center, 70, paint);

    // Pulsing outer warning circles
    for (int i = 0; i < 3; i++) {
      final t = (progress + i / 3.0) % 1.0;
      paint.color = Colors.redAccent.withOpacity((1.0 - t) * 0.35);
      paint.strokeWidth = 1.5 + (1.0 - t) * 3.0;
      canvas.drawCircle(center, 50 + t * 45, paint);
    }

    // Inner filled core
    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.redAccent;
    canvas.drawCircle(center, 40, innerPaint);

    // Draw chair hazard logo inside core
    final iconPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Simple stick figure sitting
    canvas.drawLine(center + const Offset(-15, -15), center + const Offset(-15, 0), iconPaint); // Back
    canvas.drawLine(center + const Offset(-15, 0), center + const Offset(10, 0), iconPaint);   // Thighs
    canvas.drawLine(center + const Offset(10, 0), center + const Offset(10, 20), iconPaint);   // Legs
    canvas.drawCircle(center + const Offset(-15, -23), 5, Paint()..color = Colors.white);     // Head
  }

  @override
  bool shouldRepaint(covariant _PulseWarningPainter oldDelegate) => true;
}

class _LiverGraphic extends StatefulWidget {
  final bool isDark;
  const _LiverGraphic({required this.isDark});

  @override
  State<_LiverGraphic> createState() => _LiverGraphicState();
}

class _LiverGraphicState extends State<_LiverGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _LiverPainter(
            pulse: _controller.value,
            isDark: widget.isDark,
          ),
        );
      },
    );
  }
}

class _LiverPainter extends CustomPainter {
  final double pulse;
  final bool isDark;
  _LiverPainter({required this.pulse, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Draw background health rings
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.orangeAccent.withOpacity(0.08);
    canvas.drawCircle(center, 70, ringPaint);
    canvas.drawCircle(center, 85 + pulse * 10, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.orangeAccent.withOpacity(0.03 + (1.0 - pulse) * 0.08));

    // Vector drawing of the liver organ shape
    final path = Path();
    
    // Main large lobe
    path.moveTo(center.dx - 55, center.dy + 15);
    path.quadraticBezierTo(
      center.dx - 30, center.dy - 40,
      center.dx + 45, center.dy - 35,
    );
    path.quadraticBezierTo(
      center.dx + 70, center.dy - 25,
      center.dx + 65, center.dy + 5,
    );
    path.quadraticBezierTo(
      center.dx + 40, center.dy + 35,
      center.dx - 20, center.dy + 35,
    );
    path.quadraticBezierTo(
      center.dx - 45, center.dy + 30,
      center.dx - 55, center.dy + 15,
    );
    path.close();

    final liverPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: 60))
      ..style = PaintingStyle.fill;
      
    canvas.drawPath(path, liverPaint);

    // Draw yellow lipid warning dots (Fat accumulation representation)
    final lipidPaint = Paint()..color = Colors.yellowAccent.withOpacity(0.6 + pulse * 0.4);
    
    canvas.drawCircle(center + const Offset(15, -15), 4, lipidPaint);
    canvas.drawCircle(center + const Offset(-5, -5), 3, lipidPaint);
    canvas.drawCircle(center + const Offset(30, -5), 5.5, lipidPaint);
    canvas.drawCircle(center + const Offset(5, 10), 3.5, lipidPaint);
    canvas.drawCircle(center + const Offset(-25, 10), 4.5, lipidPaint);

    // Hazard warning icon overlaying the liver
    final alertPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.fill;
    
    final alertCenter = center + const Offset(45, 25);
    
    // Draw triangle warning badge
    final triPath = Path();
    triPath.moveTo(alertCenter.dx, alertCenter.dy - 12);
    triPath.lineTo(alertCenter.dx - 12, alertCenter.dy + 10);
    triPath.lineTo(alertCenter.dx + 12, alertCenter.dy + 10);
    triPath.close();
    canvas.drawPath(triPath, alertPaint);

    // Draw exclamation mark inside warning triangle
    final textPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(alertCenter + const Offset(0, -3), alertCenter + const Offset(0, 3), textPaint);
    canvas.drawCircle(alertCenter + const Offset(0, 6), 1, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant _LiverPainter oldDelegate) => true;
}

class _TrackerRingGraphic extends StatefulWidget {
  final bool isDark;
  final Color accentColor;
  const _TrackerRingGraphic({required this.isDark, required this.accentColor});

  @override
  State<_TrackerRingGraphic> createState() => _TrackerRingGraphicState();
}

class _TrackerRingGraphicState extends State<_TrackerRingGraphic> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _TrackerRingPainter(
            angle: _controller.value * 2 * pi,
            isDark: widget.isDark,
            accentColor: widget.accentColor,
          ),
        );
      },
    );
  }
}

class _TrackerRingPainter extends CustomPainter {
  final double angle;
  final bool isDark;
  final Color accentColor;
  _TrackerRingPainter({required this.angle, required this.isDark, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    // Inactive background ring
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..color = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.04);
    canvas.drawCircle(center, 65, bgPaint);

    // Active animated ring (representing countdown/steps progress)
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [accentColor.withOpacity(0.1), accentColor, const Color(0xFF10B981)],
        transform: GradientRotation(angle),
      ).createShader(Rect.fromCircle(center: center, radius: 65));
      
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 65),
      -pi / 2,
      1.5 * pi, // 75% complete ring
      false,
      progressPaint,
    );

    // Draw active center shield with checkmark
    final shieldPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 40, shieldPaint);

    // Checkmark inside shield
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
      
    final checkPath = Path();
    checkPath.moveTo(center.dx - 12, center.dy);
    checkPath.lineTo(center.dx - 3, center.dy + 9);
    checkPath.lineTo(center.dx + 12, center.dy - 8);
    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant _TrackerRingPainter oldDelegate) => true;
}
