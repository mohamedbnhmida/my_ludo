import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:ludo_flutter/ludo_player.dart';
import 'package:ludo_flutter/ludo_provider.dart';

void main() {
  test('checkToKill sends an opponent pawn home when landed on', () {
    var provider = LudoProvider();
    var mover = LudoPlayer(LudoPlayerType.green);
    var victim = LudoPlayer(LudoPlayerType.yellow);
    provider.players.addAll([mover, victim]);

    // Find a cell shared by both paths (the common outer track) that isn't a safe cell.
    int moverStep = -1, victimStep = -1;
    outer:
    for (int i = 0; i < mover.path.length; i++) {
      for (int j = 0; j < victim.path.length; j++) {
        bool safe = LudoPath.safeArea.map((e) => e.toString()).contains(mover.path[i].toString());
        if (!safe && mover.path[i].toString() == victim.path[j].toString()) {
          moverStep = i;
          victimStep = j;
          break outer;
        }
      }
    }
    expect(moverStep, isNot(-1), reason: 'no shared non-safe cell found between green and yellow paths');

    victim.movePawn(0, victimStep);
    mover.movePawn(0, moverStep);

    bool killed = provider.checkToKill(LudoPlayerType.green, 0, moverStep + 1, mover.path);

    expect(killed, isTrue, reason: 'landing on an opponent pawn should report a kill');
    expect(victim.pawns[0].step, -1, reason: 'the killed pawn should be sent back home');
  });
}
