import 'package:just_audio/just_audio.dart';

class Audio {
  // One player per sound category: move ticks fire every ~150ms during a multi-step
  // move, and a shared single player would race a rapid tick against the finish/kill
  // sound that follows immediately after, sometimes silently swallowing the latter.
  static final AudioPlayer _movePlayer = AudioPlayer();
  static final AudioPlayer _killPlayer = AudioPlayer();
  static final AudioPlayer _finishPlayer = AudioPlayer();
  static final AudioPlayer _rollPlayer = AudioPlayer();

  ///Global mute toggle, set from the menu screen
  static bool muted = false;

  static Future<void> playMove() async {
    if (muted) return;
    var duration = await _movePlayer.setAsset('assets/sounds/move.wav');
    _movePlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }

  static Future<void> playKill() async {
    if (muted) return;
    var duration = await _killPlayer.setAsset('assets/sounds/laugh.mp3');
    _killPlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }

  ///Plays when a pawn reaches the last cell of its path (the arrow into the finish triangle).
  static Future<void> playFinish() async {
    if (muted) return;
    var duration = await _finishPlayer.setAsset('assets/sounds/finish.wav');
    _finishPlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }

  static Future<void> rollDice() async {
    if (muted) return;
    var duration = await _rollPlayer.setAsset('assets/sounds/roll_the_dice.mp3');
    _rollPlayer.play();
    return Future.delayed(duration ?? Duration.zero);
  }
}
