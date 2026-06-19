import 'dart:math';
import 'package:flutter/material.dart';

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double rotation;
  double rotationSpeed;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ConfettiCanvas extends StatefulWidget {
  final int triggerCount;
  const ConfettiCanvas({super.key, required this.triggerCount});

  @override
  State<ConfettiCanvas> createState() => _ConfettiCanvasState();
}

class _ConfettiCanvasState extends State<ConfettiCanvas> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        _updateParticles();
      });
  }

  @override
  void didUpdateWidget(ConfettiCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.triggerCount > oldWidget.triggerCount) {
      _spawnParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _spawnParticles() {
    _particles.clear();
    final colors = [
      Colors.blueAccent,
      Colors.pinkAccent,
      Colors.amberAccent,
      Colors.purpleAccent,
      Colors.greenAccent,
      Colors.orangeAccent,
      Colors.cyanAccent,
    ];
    
    // Perform layout coordinates fetch
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;
    
    // Spawn 120 particles shooting up from the bottom-left and bottom-right corners
    for (int i = 0; i < 120; i++) {
      final fromLeft = _random.nextBool();
      final startX = fromLeft ? 0.0 : screenWidth;
      final startY = screenHeight * 0.85;
      
      // Speed vectors: shooting up and inwards
      final vx = (fromLeft ? 4.0 : -4.0) + _random.nextDouble() * 10.0 * (fromLeft ? 1.0 : -1.0);
      final vy = -12.0 - _random.nextDouble() * 14.0;

      _particles.add(ConfettiParticle(
        x: startX,
        y: startY,
        vx: vx,
        vy: vy,
        size: 8.0 + _random.nextDouble() * 10.0,
        color: colors[_random.nextInt(colors.length)],
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: -0.15 + _random.nextDouble() * 0.3,
      ));
    }
  }

  void _updateParticles() {
    const gravity = 0.42;
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      p.vy += gravity; // Pull down
      p.vx *= 0.98;    // Air drag
      p.rotation += p.rotationSpeed;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty || !_controller.isAnimating) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(particles: _particles),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;
  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var p in particles) {
      paint.color = p.color;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      
      // Draw rectangular confetti paper ribbons
      final rect = Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
