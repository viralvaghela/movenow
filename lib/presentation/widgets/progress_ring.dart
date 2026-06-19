import 'dart:math';
import 'package:flutter/material.dart';

class ProgressRing extends StatelessWidget {
  final double timeProgress; // 0.0 to 1.0 (elapsed inactivity time)
  final double walkProgress; // 0.0 to 1.0 (walk distance completed)
  final String centerText;
  final String subtitleText;
  final bool isAlarmActive;

  const ProgressRing({
    super.key,
    required this.timeProgress,
    required this.walkProgress,
    required this.centerText,
    required this.subtitleText,
    this.isAlarmActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size.width * 0.65;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: timeProgress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedTime, _) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: walkProgress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, animatedWalk, _) {
                  return CustomPaint(
                    size: Size(size, size),
                    painter: _ProgressRingPainter(
                      timeProgress: animatedTime,
                      walkProgress: animatedWalk,
                      timeColor: isAlarmActive ? Colors.red : theme.colorScheme.primary,
                      walkColor: const Color(0xFF10B981),
                      inactiveColor: theme.brightness == Brightness.dark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      isAlarmActive: isAlarmActive,
                    ),
                  );
                },
              );
            },
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerText,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isAlarmActive ? Colors.redAccent : theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double timeProgress;
  final double walkProgress;
  final Color timeColor;
  final Color walkColor;
  final Color inactiveColor;
  final bool isAlarmActive;

  _ProgressRingPainter({
    required this.timeProgress,
    required this.walkProgress,
    required this.timeColor,
    required this.walkColor,
    required this.inactiveColor,
    this.isAlarmActive = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (min(size.width, size.height) / 2) - 10;
    final innerRadius = outerRadius - 20;

    // Paints
    final bgPaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final outerPaint = Paint()
      ..shader = LinearGradient(
        colors: isAlarmActive 
            ? [Colors.red, Colors.deepOrange]
            : [timeColor, timeColor.withOpacity(0.6)],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final innerPaint = Paint()
      ..shader = LinearGradient(
        colors: [walkColor, walkColor.withOpacity(0.6)],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // 1. Draw Outer Ring (Inactivity Time Elapsed)
    bgPaint.strokeWidth = 14;
    canvas.drawCircle(center, outerRadius, bgPaint);

    outerPaint.strokeWidth = 14;
    final outerSweepAngle = 2 * pi * timeProgress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: outerRadius),
      -pi / 2,
      outerSweepAngle,
      false,
      outerPaint,
    );

    // 2. Draw Inner Ring (Walking Progress)
    bgPaint.strokeWidth = 8;
    canvas.drawCircle(center, innerRadius, bgPaint);

    innerPaint.strokeWidth = 8;
    final innerSweepAngle = 2 * pi * walkProgress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius),
      -pi / 2,
      innerSweepAngle,
      false,
      innerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.timeProgress != timeProgress ||
        oldDelegate.walkProgress != walkProgress ||
        oldDelegate.timeColor != timeColor ||
        oldDelegate.isAlarmActive != isAlarmActive;
  }
}
