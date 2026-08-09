import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ludo_flutter/ludo_player.dart';
import 'package:provider/provider.dart';

import 'audio.dart';
import 'constants.dart';

class LudoProvider extends ChangeNotifier {
  ///Flags to check if pawn is moving
  bool _isMoving = false;

  ///Flags to stop pawn once disposed
  bool _stopMoving = false;

  LudoGameState _gameState = LudoGameState.throwDice;

  ///Game state to check if the game is in throw dice state or pick pawn state
  LudoGameState get gameState => _gameState;

  LudoPlayerType _currentTurn = LudoPlayerType.green;

  int _diceResult = 0;

  ///Dice result to check the dice result of the current turn
  int get diceResult {
    if (_diceResult < 1) {
      return 1;
    } else {
      if (_diceResult > 6) {
        return 6;
      } else {
        return _diceResult;
      }
    }
  }

  bool _diceStarted = false;
  bool get diceStarted => _diceStarted;

  LudoPlayer get currentPlayer => players.firstWhere((element) => element.type == _currentTurn);

  ///Player types taking part in the current game, in turn order
  List<LudoPlayerType> activePlayerTypes = LudoPlayerType.values;

  ///Player types controlled by the CPU instead of the local player
  Set<LudoPlayerType> cpuTypes = {};

  Timer? _cpuTimer;

  ///Fill all players
  final List<LudoPlayer> players = [];

  ///Player win, we use `LudoPlayerType` to make it easier to check
  final List<LudoPlayerType> winners = [];

  LudoPlayer player(LudoPlayerType type) => players.firstWhere((element) => element.type == type);

  ///This method will check if the pawn can kill another pawn or not by checking the step of the pawn
  bool checkToKill(LudoPlayerType type, int index, int step, List<List<double>> path) {
    bool killSomeone = false;
    for (var other in players) {
      if (other.type == type) continue;
      for (int i = 0; i < other.pawns.length; i++) {
        var pawn = other.pawns[i];
        if (pawn.step == -1) continue;
        if (LudoPath.safeArea.map((e) => e.toString()).contains(other.path[pawn.step].toString())) continue;
        if (other.path[pawn.step].toString() == path[step - 1].toString()) {
          killSomeone = true;
          other.movePawn(i, -1);
          notifyListeners();
        }
      }
    }
    return killSomeone;
  }

  ///This is the function that will be called to throw the dice
  void throwDice() async {
    if (_gameState != LudoGameState.throwDice) return;
    _diceStarted = true;
    notifyListeners();
    Audio.rollDice();

    //Check if already win skip
    if (winners.contains(currentPlayer.type)) {
      nextTurn();
      return;
    }

    //Turn off highlight for all pawns
    currentPlayer.highlightAllPawns(false);

    Future.delayed(const Duration(seconds: 1)).then((value) {
      _diceStarted = false;
      var random = Random();
      _diceResult = random.nextInt(6) + 1; //Random between 1 - 6, each face equally likely
      notifyListeners();

      if (diceResult == 6) {
        currentPlayer.highlightAllPawns();
        _gameState = LudoGameState.pickPawn;
        notifyListeners();
      } else {
        /// all pawns are inside home
        if (currentPlayer.pawnInsideCount == 4) {
          return nextTurn();
        } else {
          ///Hightlight all pawn outside
          currentPlayer.highlightOutside();
          _gameState = LudoGameState.pickPawn;
          notifyListeners();
        }
      }

      ///Check and disable if any pawn already in the finish box
      for (var i = 0; i < currentPlayer.pawns.length; i++) {
        var pawn = currentPlayer.pawns[i];
        if ((pawn.step + diceResult) > currentPlayer.path.length - 1) {
          currentPlayer.highlightPawn(i, false);
        }
      }

      ///Automatically move random pawn if all pawn are in same step
      var moveablePawn = currentPlayer.pawns.where((e) => e.highlight).toList();
      if (moveablePawn.length > 1) {
        var biggestStep = moveablePawn.map((e) => e.step).reduce(max);
        if (moveablePawn.every((element) => element.step == biggestStep)) {
          var random = 1 + Random().nextInt(moveablePawn.length - 1);
          if (moveablePawn[random].step == -1) {
            var thePawn = moveablePawn[random];
            move(thePawn.type, thePawn.index, (thePawn.step + 1) + 1);
            return;
          } else {
            var thePawn = moveablePawn[random];
            move(thePawn.type, thePawn.index, (thePawn.step + 1) + diceResult);
            return;
          }
        }
      }

      ///If User have 6 dice, but it inside finish line, it will make him to throw again, else it will turn to next player
      if (currentPlayer.pawns.every((element) => !element.highlight)) {
        if (diceResult == 6) {
          _gameState = LudoGameState.throwDice;
        } else {
          nextTurn();
          return;
        }
      }

      if (currentPlayer.pawns.where((element) => element.highlight).length == 1) {
        var index = currentPlayer.pawns.indexWhere((element) => element.highlight);
        move(currentPlayer.type, index, (currentPlayer.pawns[index].step + 1) + diceResult);
      }
    });
  }

  ///Move pawn to next step and check if it can kill other pawn
  void move(LudoPlayerType type, int index, int step) async {
    if (_isMoving) return;
    _isMoving = true;
    _gameState = LudoGameState.moving;

    currentPlayer.highlightAllPawns(false);

    // int delay = 500;
    var selectedPlayer = player(type);
    for (int i = selectedPlayer.pawns[index].step; i < step; i++) {
      if (_stopMoving) break;
      if (selectedPlayer.pawns[index].step == i) continue;
      selectedPlayer.movePawn(index, i);
      Audio.playMove(); // fire-and-forget: don't block each hop on the full clip length
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 150));
      if (_stopMoving) break;
    }
    bool justFinished = selectedPlayer.pawns[index].step == selectedPlayer.path.length - 1;
    if (justFinished) {
      Audio.playFinish();
    }
    if (checkToKill(type, index, step, selectedPlayer.path)) {
      _gameState = LudoGameState.throwDice;
      _isMoving = false;
      Audio.playKill();
      notifyListeners();
      return;
    }

    validateWin(type);

    ///Rolling a 6, or landing a pawn on the last cell of its path, earns another roll.
    if (diceResult == 6 || justFinished) {
      _gameState = LudoGameState.throwDice;
      notifyListeners();
    } else {
      nextTurn();
      notifyListeners();
    }
    _isMoving = false;
  }

  ///Next turn will be called when the player finish the turn
  void nextTurn() {
    int index = activePlayerTypes.indexOf(_currentTurn);
    _currentTurn = activePlayerTypes[(index + 1) % activePlayerTypes.length];

    if (winners.contains(_currentTurn)) return nextTurn();
    _gameState = LudoGameState.throwDice;
    notifyListeners();
  }

  ///This function will check if the pawn finish the game or not
  void validateWin(LudoPlayerType color) {
    if (winners.map((e) => e.name).contains(color.name)) return;
    if (player(color).pawns.map((e) => e.step).every((element) => element == player(color).path.length - 1)) {
      winners.add(color);
      notifyListeners();
    }

    if (winners.length == activePlayerTypes.length - 1) {
      _gameState = LudoGameState.finish;
    }
  }

  ///Start a new game with [numberOfPlayers] (2, 3 or 4). 2 players play diagonally opposite corners.
  ///When [vsCpu] is true, every player but the first is controlled by the CPU.
  void startGame({int numberOfPlayers = 4, bool vsCpu = false}) {
    winners.clear();
    players.clear();
    activePlayerTypes = numberOfPlayers == 2
        ? [LudoPlayerType.green, LudoPlayerType.blue]
        : LudoPlayerType.values.take(numberOfPlayers).toList();
    cpuTypes = vsCpu ? activePlayerTypes.skip(1).toSet() : {};
    _currentTurn = activePlayerTypes.first;
    _gameState = LudoGameState.throwDice;
    players.addAll(activePlayerTypes.map((type) => LudoPlayer(type)));

    _cpuTimer?.cancel();
    _cpuTimer = Timer.periodic(const Duration(milliseconds: 400), (_) => _cpuTick());
  }

  ///Drives CPU-controlled players: rolls the dice and picks a highlighted pawn for them.
  void _cpuTick() {
    if (_gameState == LudoGameState.finish) {
      _cpuTimer?.cancel();
      return;
    }
    if (!cpuTypes.contains(_currentTurn)) return;

    if (_gameState == LudoGameState.throwDice && !_diceStarted) {
      throwDice();
    } else if (_gameState == LudoGameState.pickPawn) {
      var movablePawn = currentPlayer.pawns.where((e) => e.highlight).toList();
      if (movablePawn.isEmpty) return;
      var pawn = movablePawn.first;
      move(pawn.type, pawn.index, pawn.step == -1 ? 1 : (pawn.step + 1) + diceResult);
    }
  }

  @override
  void dispose() {
    _stopMoving = true;
    _cpuTimer?.cancel();
    super.dispose();
  }

  static LudoProvider read(BuildContext context) => context.read();
}
