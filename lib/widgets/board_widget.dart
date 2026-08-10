import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:ludo_flutter/ludo_provider.dart';
import 'package:ludo_flutter/widgets/pawn_widget.dart';
import 'package:provider/provider.dart';

import '../ludo_player.dart';

///Widget for the board
class BoardWidget extends StatelessWidget {
  const BoardWidget({super.key});

  ///Margin around the colored board (for its shadow/rounded outer corner). Callers that
  ///lay out siblings around the board need this to compute its true total footprint,
  ///since `ludoBoard` only reports the inner colored-board size.
  static const double margin = 10;

  ///Return board size
  static double ludoBoard(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 500) {
      return 500;
    } else {
      if (width < 300) {
        return 300;
      } else {
        return width - 20;
      }
    }
  }

  ///Count box size
  static double boxStepSize(BuildContext context) {
    return ludoBoard(context) / 15;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(margin),
      clipBehavior: Clip.antiAlias,
      width: ludoBoard(context),
      height: ludoBoard(context),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        image: const DecorationImage(
          image: AssetImage("assets/images/board.png"),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: Consumer<LudoProvider>(
        builder: (context, value, child) {
          //We use `Stack` to put all widgets on top of each other
          //so we make some logic to change the order of players to make sure
          //the player on top is the one who is playing
          List<LudoPlayer> players = List.from(value.players);
          Map<String, List<PawnWidget>> pawnsRaw = {};
          Map<String, List<String>> pawnsToPrint = {};
          List<Widget> playersPawn = [];

          //Sort players by current turn to make sure the player on top is the one who is playing
          players.sort((a, b) => value.currentPlayer.type == a.type ? 1 : -1);

          ///Loop through all players and add their pawns to the map
          for (int i = 0; i < players.length; i++) {
            var player = players[i];
            for (int j = 0; j < player.pawns.length; j++) {
              var pawn = player.pawns[j];
              if (pawn.step > -1) {
                String step = player.path[pawn.step].toString();
                if (pawnsRaw[step] == null) {
                  pawnsRaw[step] = [];
                  pawnsToPrint[step] = [];
                }
                pawnsRaw[step]!.add(pawn);
                pawnsToPrint[step]!.add(player.type.toString());
              } else {
                if (pawnsRaw["home"] == null) {
                  pawnsRaw["home"] = [];
                  pawnsToPrint["home"] = [];
                }
                pawnsRaw["home"]!.add(pawn);
                pawnsToPrint["home"]!.add(player.type.toString());
              }
            }
          }

          for (int i = 0; i < pawnsRaw.keys.length; i++) {
            String key = pawnsRaw.keys.elementAt(i);
            List<PawnWidget> pawnsValue = pawnsRaw[key]!;

            /// This is for every pawn in home
            if (key == "home") {
              playersPawn.addAll(
                pawnsValue.map((e) {
                  var player = value.players.firstWhere((element) => element.type == e.type);
                  double left = LudoPath.stepBox(ludoBoard(context), player.homePath[e.index][0]);
                  double top = LudoPath.stepBox(ludoBoard(context), player.homePath[e.index][1]);
                  return AnimatedPositioned(
                    key: ValueKey("${e.type.name}_${e.index}"),
                    left: left,
                    top: top,
                    width: boxStepSize(context),
                    height: boxStepSize(context),
                    duration: const Duration(milliseconds: 200),
                    child: _JumpBounce(position: Offset(left, top), child: e),
                  );
                }),
              );
            } else {
              // This is for every pawn in path (not in home)
              // I'm so lazy, so make it simple h3h3
              List<double> coordinates = key.replaceAll("[", "").replaceAll("]", "").split(",").map((e) => double.parse(e.trim())).toList();

              if (pawnsValue.length == 1) {
                // This is for 1 pawn in 1 box
                var e = pawnsValue.first;
                double left = LudoPath.stepBox(ludoBoard(context), coordinates[0]);
                double top = LudoPath.stepBox(ludoBoard(context), coordinates[1]);
                bool isFinal = e.step == value.players.firstWhere((p) => p.type == e.type).path.length - 1;
                playersPawn.add(AnimatedPositioned(
                  key: ValueKey("${e.type.name}_${e.index}"),
                  duration: const Duration(milliseconds: 200),
                  left: left,
                  top: top,
                  width: boxStepSize(context),
                  height: boxStepSize(context),
                  child: _JumpBounce(position: Offset(left, top), isFinal: isFinal, child: pawnsValue.first),
                ));
              } else {
                // This is for more than 1 pawn in 1 box
                playersPawn.addAll(
                  List.generate(
                    pawnsValue.length,
                    (index) {
                      var e = pawnsValue[index];
                      double left = LudoPath.stepBox(ludoBoard(context), coordinates[0]) + (index * 3);
                      double top = LudoPath.stepBox(ludoBoard(context), coordinates[1]);
                      bool isFinal = e.step == value.players.firstWhere((p) => p.type == e.type).path.length - 1;
                      return AnimatedPositioned(
                        key: ValueKey("${e.type.name}_${e.index}"),
                        duration: const Duration(milliseconds: 200),
                        left: left,
                        top: top,
                        width: boxStepSize(context) - 5,
                        height: boxStepSize(context),
                        child: _JumpBounce(position: Offset(left, top), isFinal: isFinal, child: pawnsValue[index]),
                      );
                    },
                  ),
                );
              }
            }
          }

          return Center(
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                ...playersPawn,
                ...winners(context, value.winners),
                cornerOverlay(context, value.currentPlayer.type, value.currentPlayer.color),
              ],
            ),
          );
        },
      ),
    );
  }

  ///This is for the current player's home-square overlay: a pulsing darken/flash on the square
  ///while it's their turn. Identity (avatar/name) is shown in the chip above their dice instead.
  Widget cornerOverlay(BuildContext context, LudoPlayerType type, Color color) {
    var (x, y) = LudoPath.corner(type);
    // Only the true outer corner of the board is rounded; the other 3 edges of
    // a home square are straight, meeting the cross-shaped track or another square.
    BorderRadius radius = BorderRadius.only(
      topLeft: Radius.circular(x == 0 && y == 0 ? 40 : 0),
      topRight: Radius.circular(x == 1 && y == 0 ? 40 : 0),
      bottomLeft: Radius.circular(x == 0 && y == 1 ? 40 : 0),
      bottomRight: Radius.circular(x == 1 && y == 1 ? 40 : 0),
    );
    return Positioned(
      top: y == 0 ? 0 : null,
      left: x == 0 ? 0 : null,
      right: x == 1 ? 0 : null,
      bottom: y == 1 ? 0 : null,
      width: ludoBoard(context) * .4,
      height: ludoBoard(context) * .4,
      child: IgnorePointer(
        child: ClipRRect(borderRadius: radius, child: _TurnPulse(color: color)),
      ),
    );
  }

  ///This is for the winner widget
  List<Widget> winners(BuildContext context, List<LudoPlayerType> winners) => List.generate(
        winners.length,
        (index) {
          Widget crownImage = Image.asset("assets/games/ludo/crown/1st.png");

          if (index == 0) {
            crownImage = Image.asset("assets/images/crown/1st.png", fit: BoxFit.cover);
          } else if (index == 1) {
            crownImage = Image.asset("assets/images/crown/2nd.png", fit: BoxFit.cover);
          } else if (index == 2) {
            crownImage = Image.asset("assets/images/crown/3rd.png", fit: BoxFit.cover);
          } else {
            return Container();
          }

          var (x, y) = LudoPath.corner(winners[index]);
          return Positioned(
            top: y == 0 ? 0 : null,
            left: x == 0 ? 0 : null,
            right: x == 1 ? 0 : null,
            bottom: y == 1 ? 0 : null,
            width: ludoBoard(context) * .4,
            height: ludoBoard(context) * .4,
            child: Padding(
              padding: EdgeInsets.all(boxStepSize(context)),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
                child: crownImage,
              ),
            ),
          );
        },
      );
}

///Scales the pawn up then back down whenever it lands on a new cell, to read as a little jump/hop.
///When it lands on the last cell of its path (the arrow into the finish triangle), it gets a
///bigger celebratory pop with a full spin instead of the regular small hop.
class _JumpBounce extends StatefulWidget {
  final Offset position;
  final bool isFinal;
  final Widget child;
  const _JumpBounce({required this.position, this.isFinal = false, required this.child});

  @override
  State<_JumpBounce> createState() => _JumpBounceState();
}

class _JumpBounceState extends State<_JumpBounce> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: Duration(milliseconds: widget.isFinal ? 500 : 200));
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: widget.isFinal ? 1.8 : 1.4).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
    TweenSequenceItem(
      tween: Tween(begin: widget.isFinal ? 1.8 : 1.4, end: 1.0).chain(CurveTween(curve: widget.isFinal ? Curves.elasticOut : Curves.easeIn)),
      weight: 50,
    ),
  ]).animate(_controller);
  late final Animation<double> _spin = widget.isFinal
      ? Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut))
      : const AlwaysStoppedAnimation(0);

  @override
  void didUpdateWidget(covariant _JumpBounce oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(angle: _spin.value * 2 * pi, child: Transform.scale(scale: _scale.value, child: child)),
      child: widget.child,
    );
  }
}

///Pulsing darken/flash overlay for the active player's home square.
class _TurnPulse extends StatefulWidget {
  final Color color;
  const _TurnPulse({required this.color});

  @override
  State<_TurnPulse> createState() => _TurnPulseState();
}

class _TurnPulseState extends State<_TurnPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15 + 0.25 * _controller.value),
          border: Border.all(color: widget.color.withValues(alpha: 0.4 + 0.6 * _controller.value), width: 3),
        ),
      ),
    );
  }
}
