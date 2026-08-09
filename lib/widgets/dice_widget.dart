import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:ludo_flutter/ludo_provider.dart';
import 'package:provider/provider.dart';
import 'package:simple_ripple_animation/simple_ripple_animation.dart';

///Widget for a single player's dice. Only the active player's dice is live; the rest sit dimmed.
class DiceWidget extends StatelessWidget {
  final LudoPlayerType type;

  const DiceWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<LudoProvider>(
      builder: (context, value, child) {
        bool isActive = value.currentPlayer.type == type;
        if (!isActive) {
          return IgnorePointer(
            child: Opacity(
              opacity: 0.6,
              child: Image.asset("assets/images/dice/1.png", fit: BoxFit.contain),
            ),
          );
        }
        return RippleAnimation(
          color: value.gameState == LudoGameState.throwDice ? value.currentPlayer.color : Colors.white.withValues(alpha: 0),
          ripplesCount: 3,
          minRadius: 30,
          repeat: true,
          child: CupertinoButton(
            onPressed: value.cpuTypes.contains(value.currentPlayer.type) ? null : value.throwDice,
            padding: const EdgeInsets.only(),
            child: value.diceStarted ? Image.asset("assets/images/dice/draw.gif", fit: BoxFit.contain) : Image.asset("assets/images/dice/${value.diceResult}.png", fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}
