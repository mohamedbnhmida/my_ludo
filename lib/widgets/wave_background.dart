import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ludo_flutter/constants.dart';

///Self-ticking animated wave backdrop, shared by the menu and the game screen.
class WaveBackground extends StatefulWidget {
  const WaveBackground({super.key});

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(painter: LudoWavePainter(_controller.value), size: Size.infinite),
    );
  }
}

///Layered sine waves drifting across the bottom of the screen.
class LudoWavePainter extends CustomPainter {
  final double t;
  LudoWavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(canvas, size, color: AppTheme.turquoiseLight.withValues(alpha: 0.35), heightFactor: 0.16, phase: t * 2 * pi, speed: 1);
    _drawWave(canvas, size, color: AppTheme.turquoiseMid.withValues(alpha: 0.45), heightFactor: 0.11, phase: t * 2 * pi + pi / 2, speed: 1.3);
    _drawWave(canvas, size, color: AppTheme.turquoiseDark.withValues(alpha: 0.6), heightFactor: 0.08, phase: t * 2 * pi + pi, speed: 0.8);
  }

  void _drawWave(Canvas canvas, Size size, {required Color color, required double heightFactor, required double phase, required double speed}) {
    final paint = Paint()..color = color;
    final path = Path();
    final baseHeight = size.height * (1 - heightFactor);
    path.moveTo(0, size.height);
    path.lineTo(0, baseHeight);
    for (double x = 0; x <= size.width; x += 4) {
      final y = baseHeight + sin((x / size.width * 2 * pi * speed) + phase) * (size.height * heightFactor * 0.5);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant LudoWavePainter oldDelegate) => oldDelegate.t != t;
}
