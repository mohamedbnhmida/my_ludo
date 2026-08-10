import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio.dart';
import 'constants.dart';
import 'ludo_provider.dart';
import 'main_screen.dart';
import 'widgets/wave_background.dart';

///Start menu shown when the app launches: pick sound, player count and CPU, then start.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  bool _soundOn = !Audio.muted;
  int _playerCount = 4;
  bool _vsCpu = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    Audio.muted = !_soundOn;
    context.read<LudoProvider>().startGame(numberOfPlayers: _playerCount, vsCpu: _vsCpu);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppTheme.backgroundGradient,
                  ),
                ),
              ),
              CustomPaint(painter: LudoWavePainter(_controller.value), size: Size.infinite),
              const Positioned.fill(child: DiceRain()),
              child!,
            ],
          );
        },
        child: _MenuContent(
          titleAnimation: _controller,
          soundOn: _soundOn,
          playerCount: _playerCount,
          vsCpu: _vsCpu,
          onSoundToggle: () => setState(() => _soundOn = !_soundOn),
          onPlayerCountChanged: (n) => setState(() => _playerCount = n),
          onCpuToggle: () => setState(() => _vsCpu = !_vsCpu),
          onStart: _start,
        ),
      ),
    );
  }
}

class _MenuContent extends StatelessWidget {
  final Animation<double> titleAnimation;
  final bool soundOn;
  final int playerCount;
  final bool vsCpu;
  final VoidCallback onSoundToggle;
  final ValueChanged<int> onPlayerCountChanged;
  final VoidCallback onCpuToggle;
  final VoidCallback onStart;

  const _MenuContent({
    required this.titleAnimation,
    required this.soundOn,
    required this.playerCount,
    required this.vsCpu,
    required this.onSoundToggle,
    required this.onPlayerCountChanged,
    required this.onCpuToggle,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: onSoundToggle,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: AppTheme.bubbleDecoration(active: soundOn),
                  child: Icon(soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: soundOn ? AppTheme.turquoiseDark : Colors.white, size: 24),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _title(),
                  const SizedBox(height: 8),
                  const Text("A classic board game", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                  const SizedBox(height: 48),
                  const Text("PLAYERS", style: TextStyle(color: Colors.white70, fontSize: 13, letterSpacing: 2, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _playerSelector(),
                  const SizedBox(height: 24),
                  _cpuToggle(),
                  const SizedBox(height: 40),
                  _startButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ///Gently breathing logo, reusing the background's animation controller.
  Widget _title() {
    const letters = ["L", "U", "D", "O"];
    const colors = [LudoColor.green, LudoColor.yellow, LudoColor.blue, LudoColor.red];
    return AnimatedBuilder(
      animation: titleAnimation,
      builder: (context, child) => Transform.scale(scale: 1 + 0.04 * sin(titleAnimation.value * 2 * pi), child: child),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          letters.length,
          (i) => Text(
            letters[i],
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: colors[i],
              shadows: const [Shadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playerSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [2, 3, 4].map((n) {
        final selected = n == playerCount;
        return GestureDetector(
          onTap: () => onPlayerCountChanged(n),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            width: 56,
            height: 56,
            decoration: AppTheme.bubbleDecoration(active: selected),
            alignment: Alignment.center,
            child: Text(
              "$n",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: selected ? AppTheme.turquoiseDark : Colors.white),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _cpuToggle() {
    return GestureDetector(
      onTap: onCpuToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: AppTheme.bubbleDecoration(active: !vsCpu, borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 18, color: !vsCpu ? AppTheme.turquoiseDark : Colors.white),
            const SizedBox(width: 8),
            Text("VS CPU", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: !vsCpu ? AppTheme.turquoiseDark : Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _startButton() {
    return GestureDetector(
      onTap: onStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
        decoration: AppTheme.bubbleDecoration(active: true, borderRadius: BorderRadius.circular(36)),
        child: const Text("START GAME", style: TextStyle(color: AppTheme.turquoiseDark, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
      ),
    );
  }
}
