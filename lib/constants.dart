import 'package:flutter/material.dart';

enum LudoPlayerType { green, yellow, blue, red }

enum LudoGameState { throwDice, pickPawn, moving, finish }

///Ludo colors constant class
class LudoColor {
  static const Color green = Color(0xFF1aaa30);
  static const Color yellow = Color(0xFFffcd1d);
  static const Color blue = Color(0xFF4a5fd1);
  static const Color red = Color(0xFFf84700);

  static Color of(LudoPlayerType type) => switch (type) {
        LudoPlayerType.green => green,
        LudoPlayerType.yellow => yellow,
        LudoPlayerType.blue => blue,
        LudoPlayerType.red => red,
      };
}

///Shared turquoise theme used by the menu and the in-game background
class AppTheme {
  static const Color turquoiseDark = Color(0xFF04292A);
  static const Color turquoiseMid = Color(0xFF0E7C7B);
  static const Color turquoiseLight = Color(0xFF35D0C7);

  static const List<Color> backgroundGradient = [turquoiseDark, turquoiseMid];

  ///Glossy "bubble" fill used by circular/pill buttons
  static BoxDecoration bubbleDecoration(
      {required bool active, BorderRadius? borderRadius}) {
    return BoxDecoration(
      shape: borderRadius == null ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: borderRadius,
      gradient: RadialGradient(
        center: const Alignment(-0.3, -0.4),
        radius: 1,
        colors: active
            ? const [Colors.white, turquoiseLight, turquoiseMid]
            : [
                Colors.white.withValues(alpha: 0.35),
                turquoiseMid.withValues(alpha: 0.55),
                turquoiseDark.withValues(alpha: 0.65)
              ],
        stops: const [0, 0.5, 1],
      ),
      boxShadow: [
        BoxShadow(
            color: turquoiseDark.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 4))
      ],
    );
  }
}

///Ludo path constant class which contains all the path of the pawns
class LudoPath {
  ///Calculate the path for player to move the pawn with specific step
  static double stepBox(double boardSize, double step) {
    double boxRaw = (boardSize / 15);
    double stepSize = boxRaw * step;
    return stepSize;
  }

  ///Which board corner a player's home square sits in. x: 0 = left, 1 = right. y: 0 = top, 1 = bottom.
  static (int x, int y) corner(LudoPlayerType type) {
    switch (type) {
      case LudoPlayerType.green:
        return (0, 0);
      case LudoPlayerType.yellow:
        return (1, 0);
      case LudoPlayerType.blue:
        return (1, 1);
      case LudoPlayerType.red:
        return (0, 1);
    }
  }

  ///Corners in clockwise order starting top-left; this matches `LudoPlayerType`'s enum
  ///order (green, yellow, blue, red), which is what makes `rotationSteps`/`viewCorner` below work.
  static const List<(int, int)> _cornerOrder = [(0, 0), (1, 0), (1, 1), (0, 1)];

  ///How many 90°-clockwise turns the board needs so `viewer`'s home ends up bottom-left (red's slot).
  static int rotationSteps(LudoPlayerType viewer) => (3 - viewer.index) % 4;

  ///Where `type`'s home square appears on screen once the board is rotated to put `viewer` bottom-left.
  static (int x, int y) viewCorner(LudoPlayerType type, LudoPlayerType viewer) =>
      _cornerOrder[(type.index + rotationSteps(viewer)) % 4];

  ///Safe path that is the path where the pawns can move without getting killed
  static const List<List<double>> safeArea = [
    [6, 2],
    [12, 6],
    [8, 12],
    [2, 8],
    /////////
    [8, 1],
    [13, 8],
    [6, 13],
    [1, 6],
  ];

  static const List<List<double>> greenHomePath = [
    [1.5, 1.5],
    [1.5, 3.5],
    [3.5, 1.5],
    [3.5, 3.5],
  ];
  static const List<List<double>> yellowHomePath = [
    [10.5, 1.5],
    [10.5, 3.5],
    [12.5, 1.5],
    [12.5, 3.5],
  ];
  static const List<List<double>> blueHomePath = [
    [10.5, 10.5],
    [10.5, 12.5],
    [12.5, 10.5],
    [12.5, 12.5],
  ];
  static const List<List<double>> redHomePath = [
    [1.5, 10.5],
    [1.5, 12.5],
    [3.5, 10.5],
    [3.5, 12.5],
  ];

  static const List<List<double>> greenPath = [
    ////////Green BOTTOM
    [1, 6],
    [2, 6],
    [3, 6],
    [4, 6],
    [5, 6],
    ////////Green RIGHT
    [6, 5],
    [6, 4],
    [6, 3],
    [6, 2],
    [6, 1],
    [6, 0],
    ////////GREEN TO YELLOW
    [7, 0],
    ////////YELLOW LEFT
    [8, 0],
    [8, 1],
    [8, 2],
    [8, 3],
    [8, 4],
    [8, 5],
    ////////YELLOW BOTTOM
    [9, 6],
    [10, 6],
    [11, 6],
    [12, 6],
    [13, 6],
    [14, 6],
    ////////YELLOW TO BLUE
    [14, 7],
    ////////BLUE TOP
    [14, 8],
    [13, 8],
    [12, 8],
    [11, 8],
    [10, 8],
    [9, 8],
    ////////BLUE LEFT
    [8, 9],
    [8, 10],
    [8, 11],
    [8, 12],
    [8, 13],
    [8, 14],
    ////////BLUE TO RED
    [7, 14],
    ////////RED RIGHT
    [6, 14],
    [6, 13],
    [6, 12],
    [6, 11],
    [6, 10],
    [6, 9],
    ////////RED TOP
    [5, 8],
    [4, 8],
    [3, 8],
    [2, 8],
    [1, 8],
    [0, 8],
    ////////RED TO GREEN WINNER PATH
    [0, 7],
    ////////GREEN WIN PATH
    [1, 7],
    [2, 7],
    [3, 7],
    [4, 7],
    [5, 7],
    [6, 7],
  ];
  static const List<List<double>> yellowPath = [
    ////////YELLOW LEFT
    [8, 1],
    [8, 2],
    [8, 3],
    [8, 4],
    [8, 5],
    ////////YELLOW BOTTOM
    [9, 6],
    [10, 6],
    [11, 6],
    [12, 6],
    [13, 6],
    [14, 6],
    ////////YELLOW TO BLUE
    [14, 7],
    ////////BLUE TOP
    [14, 8],
    [13, 8],
    [12, 8],
    [11, 8],
    [10, 8],
    [9, 8],
    ////////BLUE LEFT
    [8, 9],
    [8, 10],
    [8, 11],
    [8, 12],
    [8, 13],
    [8, 14],
    ////////BLUE TO RED
    [7, 14],
    ////////RED RIGHT
    [6, 14],
    [6, 13],
    [6, 12],
    [6, 11],
    [6, 10],
    [6, 9],
    ////////RED TOP
    [5, 8],
    [4, 8],
    [3, 8],
    [2, 8],
    [1, 8],
    [0, 8],
    ////////RED TO GREEN
    [0, 7],
    ////////GREEN BOTOM
    [0, 6],
    [1, 6],
    [2, 6],
    [3, 6],
    [4, 6],
    [5, 6],
    ////////GREEN RIGHT
    [6, 5],
    [6, 4],
    [6, 3],
    [6, 2],
    [6, 1],
    [6, 0],
    ////////GREEN TO YELLOW WINNER PATH
    [7, 0],
    ////////YELLOW WINNER PATH
    [7, 1],
    [7, 2],
    [7, 3],
    [7, 4],
    [7, 5],
    [7, 6],
  ];
  static const List<List<double>> bluePath = [
    ////////BLUE TOP
    [13, 8],
    [12, 8],
    [11, 8],
    [10, 8],
    [9, 8],
    ////////BLUE LEFT
    [8, 9],
    [8, 10],
    [8, 11],
    [8, 12],
    [8, 13],
    [8, 14],
    ////////BLUE TO RED
    [7, 14],
    ////////RED RIGHT
    [6, 14],
    [6, 13],
    [6, 12],
    [6, 11],
    [6, 10],
    [6, 9],
    ////////RED TOP
    [5, 8],
    [4, 8],
    [3, 8],
    [2, 8],
    [1, 8],
    [0, 8],
    ////////RED TO GREEN
    [0, 7],
    ////////GREEN BOTOM
    [0, 6],
    [1, 6],
    [2, 6],
    [3, 6],
    [4, 6],
    [5, 6],
    ////////GREEN RIGHT
    [6, 5],
    [6, 4],
    [6, 3],
    [6, 2],
    [6, 1],
    [6, 0],
    ////////GREEN TO YELLOW
    [7, 0],
    ////////YELLOW LEFT
    [8, 0],
    [8, 1],
    [8, 2],
    [8, 3],
    [8, 4],
    [8, 5],
    ////////YELLOW BOTTOM
    [9, 6],
    [10, 6],
    [11, 6],
    [12, 6],
    [13, 6],
    [14, 6],
    ////////YELLOW TO BLUE WINNER PATH
    [14, 7],
    ////////BLUE WINNER TOP
    [13, 7],
    [12, 7],
    [11, 7],
    [10, 7],
    [9, 7],
    [8, 7],
  ];
  static const List<List<double>> redPath = [
    ////////RED RIGHT
    [6, 13],
    [6, 12],
    [6, 11],
    [6, 10],
    [6, 9],
    ////////RED TOP
    [5, 8],
    [4, 8],
    [3, 8],
    [2, 8],
    [1, 8],
    [0, 8],
    ////////RED TO GREEN
    [0, 7],
    ////////GREEN BOTOM
    [0, 6],
    [1, 6],
    [2, 6],
    [3, 6],
    [4, 6],
    [5, 6],
    ////////GREEN RIGHT
    [6, 5],
    [6, 4],
    [6, 3],
    [6, 2],
    [6, 1],
    [6, 0],
    ////////GREEN TO YELLOW
    [7, 0],
    ////////YELLOW LEFT
    [8, 0],
    [8, 1],
    [8, 2],
    [8, 3],
    [8, 4],
    [8, 5],
    ////////YELLOW BOTTOM
    [9, 6],
    [10, 6],
    [11, 6],
    [12, 6],
    [13, 6],
    [14, 6],
    ////////YELLOW TO BLUE
    [14, 7],
    ////////BLUE TOP
    [14, 8],
    [13, 8],
    [12, 8],
    [11, 8],
    [10, 8],
    [9, 8],
    ////////BLUE LEFT
    [8, 9],
    [8, 10],
    [8, 11],
    [8, 12],
    [8, 13],
    [8, 14],
    ////////BLUE TO RED WINNER PATH
    [7, 14],
    ////////RED WINNER PATH
    [7, 13],
    [7, 12],
    [7, 11],
    [7, 10],
    [7, 9],
    [7, 8],
  ];
}
