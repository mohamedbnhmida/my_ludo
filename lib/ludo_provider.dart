import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ludo_flutter/ludo_player.dart';
import 'package:ludo_flutter/widgets/pawn_widget.dart';
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

  LudoPlayer get currentPlayer =>
      players.firstWhere((element) => element.type == _currentTurn);

  ///Which player's home square the board is rotated to show bottom-left. Fixed for the whole
  ///match — it never moves as turns change. vs-CPU pins it to the (single) human's color;
  ///online pins it to the local player's assigned color; local pass-and-play has no single
  ///"me", so it defaults to blue, the one color present at every player count (2, 3 and 4).
  LudoPlayerType? _fixedViewer;
  LudoPlayerType get viewerType => _fixedViewer ?? LudoPlayerType.blue;

  ///Player types taking part in the current game, in turn order
  List<LudoPlayerType> activePlayerTypes = LudoPlayerType.values;

  ///Player types controlled by the CPU instead of the local player
  Set<LudoPlayerType> cpuTypes = {};

  Timer? _cpuTimer;

  ///Fill all players
  final List<LudoPlayer> players = [];

  ///Player win, we use `LudoPlayerType` to make it easier to check
  final List<LudoPlayerType> winners = [];

  LudoPlayer player(LudoPlayerType type) =>
      players.firstWhere((element) => element.type == type);

  ///True once this provider represents an online-synced game (set by [startOnlineGame]).
  ///Gates local input: only the local player's own turn may act (see [isMyTurn]).
  bool onlineMode = false;

  ///Each online player's display name/photo, snapshotted once by LobbyScreen from the room's
  ///Firebase profile data right as the match starts — cached here so main_screen can render
  ///real name/avatar chips without re-fetching from Firebase on every frame. Empty offline.
  Map<LudoPlayerType, ({String name, String? photoBase64})> onlineProfiles = {};

  ///Whether the local player is allowed to act right now. Always true offline.
  bool get isMyTurn => !onlineMode || _currentTurn == viewerType;

  ///Set by the online wiring (see LobbyScreen) to push every locally-driven state change to
  ///Firebase. Null offline, so [_notify] there is exactly the old plain `notifyListeners()`.
  void Function(Map<String, dynamic> snapshot)? onGameChanged;

  void _notify() {
    notifyListeners();
    onGameChanged?.call({
      'currentTurn': _currentTurn.name,
      'diceResult': _diceResult,
      'gameState': _gameState.name,
      'winners': winners.map((w) => w.name).toList(),
      'pawns': {
        for (var p in players)
          p.type.name: p.pawns.map((pawn) => pawn.step).toList()
      },
    });
  }

  ///Applies a snapshot received from Firebase (i.e. a move made on another device) without
  ///re-pushing it — the existing per-pawn `AnimatedPositioned` in board_widget.dart animates
  ///the change the same way it would for a local move, since it only reacts to `step` changing.
  void applyRemoteSnapshot(Map<String, dynamic> data) {
    final turnName = data['currentTurn'] as String?;
    if (turnName != null) _currentTurn = LudoPlayerType.values.byName(turnName);
    final dice = data['diceResult'];
    if (dice != null) _diceResult = (dice as num).toInt();
    final stateName = data['gameState'] as String?;
    if (stateName != null) _gameState = LudoGameState.values.byName(stateName);
    final winnersRaw = data['winners'] as List?;
    if (winnersRaw != null) {
      winners
        ..clear()
        ..addAll(
            winnersRaw.map((w) => LudoPlayerType.values.byName(w as String)));
    }
    final pawnsRaw = data['pawns'] as Map?;
    if (pawnsRaw != null) {
      for (final entry in pawnsRaw.entries) {
        final type = LudoPlayerType.values.byName(entry.key as String);
        if (!players.any((p) => p.type == type)) continue;
        final steps = (entry.value as List).cast<num>();
        for (var i = 0; i < steps.length; i++) {
          player(type).movePawn(i, steps[i].toInt());
        }
      }
    }
    notifyListeners();
  }

  ///This method will check if the pawn can kill another pawn or not by checking the step of the pawn
  bool checkToKill(
      LudoPlayerType type, int index, int step, List<List<double>> path) {
    bool killSomeone = false;
    for (var other in players) {
      if (other.type == type) continue;
      for (int i = 0; i < other.pawns.length; i++) {
        var pawn = other.pawns[i];
        if (pawn.step == -1) continue;
        if (LudoPath.safeArea
            .map((e) => e.toString())
            .contains(other.path[pawn.step].toString())) continue;
        if (other.path[pawn.step].toString() == path[step - 1].toString()) {
          killSomeone = true;
          other.movePawn(i, -1);
          _notify();
        }
      }
    }
    return killSomeone;
  }

  ///This is the function that will be called to throw the dice
  void throwDice() async {
    if (_gameState != LudoGameState.throwDice) return;
    _diceStarted = true;
    _notify();
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
      _diceResult = random.nextInt(6) +
          1; //Random between 1 - 6, each face equally likely
      _notify();

      if (diceResult == 6) {
        currentPlayer.highlightAllPawns();
        _gameState = LudoGameState.pickPawn;
        _notify();
      } else {
        /// all pawns are inside home
        if (currentPlayer.pawnInsideCount == 4) {
          return nextTurn();
        } else {
          ///Hightlight all pawn outside
          currentPlayer.highlightOutside();
          _gameState = LudoGameState.pickPawn;
          _notify();
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

      if (currentPlayer.pawns.where((element) => element.highlight).length ==
          1) {
        var index =
            currentPlayer.pawns.indexWhere((element) => element.highlight);
        move(currentPlayer.type, index,
            (currentPlayer.pawns[index].step + 1) + diceResult);
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
      Audio
          .playMove(); // fire-and-forget: don't block each hop on the full clip length
      _notify();
      await Future.delayed(const Duration(milliseconds: 150));
      if (_stopMoving) break;
    }
    bool justFinished =
        selectedPlayer.pawns[index].step == selectedPlayer.path.length - 1;
    if (justFinished) {
      Audio.playFinish();
    }
    if (checkToKill(type, index, step, selectedPlayer.path)) {
      _gameState = LudoGameState.throwDice;
      _isMoving = false;
      Audio.playKill();
      _notify();
      return;
    }

    validateWin(type);

    ///Rolling a 6, or landing a pawn on the last cell of its path, earns another roll.
    if (diceResult == 6 || justFinished) {
      _gameState = LudoGameState.throwDice;
      _notify();
    } else {
      nextTurn();
      _notify();
    }
    _isMoving = false;
  }

  ///Next turn will be called when the player finish the turn
  void nextTurn() {
    int index = activePlayerTypes.indexOf(_currentTurn);
    _currentTurn = activePlayerTypes[(index + 1) % activePlayerTypes.length];

    if (winners.contains(_currentTurn)) return nextTurn();
    _gameState = LudoGameState.throwDice;
    _notify();
  }

  ///This function will check if the pawn finish the game or not
  void validateWin(LudoPlayerType color) {
    if (winners.map((e) => e.name).contains(color.name)) return;
    if (player(color)
        .pawns
        .map((e) => e.step)
        .every((element) => element == player(color).path.length - 1)) {
      winners.add(color);
      _notify();
    }

    if (winners.length == activePlayerTypes.length - 1) {
      _gameState = LudoGameState.finish;
    }
  }

  ///Which colors take part for a given player count. 2 players play diagonally opposite
  ///corners (green/blue); 3 or 4 take the enum in order. Shared with RoomService so online
  ///color assignment follows the exact same rule as local games.
  static List<LudoPlayerType> activeTypesFor(int numberOfPlayers) =>
      numberOfPlayers == 2
          ? [LudoPlayerType.green, LudoPlayerType.blue]
          : LudoPlayerType.values.take(numberOfPlayers).toList();

  ///Start a new local game with [numberOfPlayers] (2, 3 or 4).
  ///When [vsCpu] is true, every player but the first is controlled by the CPU.
  void startGame({int numberOfPlayers = 4, bool vsCpu = false}) {
    winners.clear();
    players.clear();
    onlineMode = false;
    onGameChanged = null;
    onlineProfiles = {};
    activePlayerTypes = activeTypesFor(numberOfPlayers);
    cpuTypes = vsCpu ? activePlayerTypes.skip(1).toSet() : {};
    // vs CPU: pin to the one human (always the first player type). Local pass-and-play has no
    // single "me" to pin to, so `viewerType`'s blue default applies (see its doc comment).
    _fixedViewer = vsCpu ? activePlayerTypes.first : null;
    _currentTurn = activePlayerTypes.first;
    _gameState = LudoGameState.throwDice;
    players.addAll(activePlayerTypes.map((type) => LudoPlayer(type)));

    _cpuTimer?.cancel();
    _cpuTimer =
        Timer.periodic(const Duration(milliseconds: 400), (_) => _cpuTick());
  }

  ///Sets up local player objects for an online room without starting the CPU loop or seeding
  ///turn/dice/pawn state — that comes moments later from Firebase via [applyRemoteSnapshot],
  ///the same way it arrives for every other device in the room (host included).
  void startOnlineGame(
      {required List<LudoPlayerType> activeTypes,
      required LudoPlayerType viewer}) {
    winners.clear();
    players.clear();
    onlineMode = true;
    activePlayerTypes = activeTypes;
    cpuTypes = {};
    _fixedViewer = viewer;
    players.addAll(activePlayerTypes.map((type) => LudoPlayer(type)));
    _cpuTimer?.cancel();
  }

  ///The 1-indexed path step `pawn` would land on this turn (matching what `move()` is called
  ///with), and whether landing there would capture an opponent's pawn sitting outside a safe cell.
  int _targetStep(PawnWidget pawn) =>
      pawn.step == -1 ? 1 : (pawn.step + 1) + diceResult;

  bool _wouldKillAt(
      LudoPlayerType type, int targetStep, List<List<double>> path) {
    final cell = path[targetStep - 1].toString();
    return players.any((other) =>
        other.type != type &&
        other.pawns.any((pawn) =>
            pawn.step != -1 &&
            !LudoPath.safeArea
                .map((e) => e.toString())
                .contains(other.path[pawn.step].toString()) &&
            other.path[pawn.step].toString() == cell));
  }

  ///Drives CPU-controlled players: rolls the dice and picks a highlighted pawn for them,
  ///preferring one that captures an opponent's pawn over just grabbing the first option.
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
      var pawn = movablePawn.firstWhere(
        (p) => _wouldKillAt(
            currentPlayer.type, _targetStep(p), currentPlayer.path),
        orElse: () => movablePawn.first,
      );
      move(pawn.type, pawn.index, _targetStep(pawn));
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
