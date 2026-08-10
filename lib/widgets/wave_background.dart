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

///Small white semi-transparent dice, each falling straight down and looping back to the
///top once it drifts past the bottom — a light decorative rain layer behind the content.
class DiceRain extends StatefulWidget {
  const DiceRain({super.key});

  @override
  State<DiceRain> createState() => _DiceRainState();
}

class _DiceRainState extends State<DiceRain> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  final List<_Drop> _drops = List.generate(16, (i) => _Drop(Random(i * 7919)));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: _drops.map((drop) => drop.build(constraints, _controller.value)).toList(),
          ),
        ),
      ),
    );
  }
}

///One falling die: randomized horizontal position, size, fall speed and start offset.
class _Drop {
  final double xFraction;
  final double size;
  final double speed;
  final double phase;
  final int face;

  _Drop(Random random)
      : xFraction = random.nextDouble(),
        size = 7 + random.nextDouble() * 11,
        speed = 0.5 + random.nextDouble() * 0.9,
        phase = random.nextDouble(),
        face = 1 + random.nextInt(6);

  Widget build(BoxConstraints constraints, double t) {
    double progress = (t * speed + phase) % 1.0;
    double top = progress * (constraints.maxHeight + size) - size;
    double left = xFraction * (constraints.maxWidth - size);
    return Positioned(
      top: top,
      left: left,
      child: CustomPaint(size: Size.square(size), painter: _DiceFacePainter(face: face)),
    );
  }
}

///Draws a single translucent white die face with genuinely transparent pips (punched
///through with `BlendMode.clear`, not just a lighter shade) at the standard 1-6 layout.
class _DiceFacePainter extends CustomPainter {
  final int face;
  const _DiceFacePainter({required this.face});

  static const Map<int, List<Offset>> _pipLayout = {
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.25, 0.75), Offset(0.75, 0.75)],
    5: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.5, 0.5), Offset(0.25, 0.75), Offset(0.75, 0.75)],
    6: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.25, 0.5), Offset(0.75, 0.5), Offset(0.25, 0.75), Offset(0.75, 0.75)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(size.shortestSide * 0.2));
    final pipRadius = size.shortestSide * 0.1;

    // saveLayer is required for BlendMode.clear to only erase within this die's
    // own painted card, instead of punching through everything behind it.
    canvas.saveLayer(rect, Paint());
    canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.22));
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    for (final pip in _pipLayout[face] ?? const []) {
      canvas.drawCircle(Offset(pip.dx * size.width, pip.dy * size.height), pipRadius, clearPaint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) => oldDelegate.face != face;
}
