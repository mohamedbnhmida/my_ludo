import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:ludo_flutter/ludo_provider.dart';
import 'package:ludo_flutter/services/profile_service.dart';
import 'package:ludo_flutter/widgets/board_widget.dart';
import 'package:ludo_flutter/widgets/dice_widget.dart';
import 'package:ludo_flutter/widgets/wave_background.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  static const double _diceBadgeSize = 52;
  static const double _avatarSize = 40;
  static const double _chipPadding =
      4; // padding around the avatar inside the pill
  static const double _chipHeight = _avatarSize + _chipPadding * 2;
  static const double _chipGap = 4;
  static const double _gapToBoard = 6;
  static const double _bottomExtraPadding =
      16; // extra breathing room below the board for the bottom dice
  static const double _outerMargin = 8;
  static const double _contentHeight = _chipHeight + _chipGap + _diceBadgeSize;
  static const double _topBand = _outerMargin + _contentHeight + _gapToBoard;
  static const double _bottomBand =
      _gapToBoard + _bottomExtraPadding + _contentHeight + _outerMargin;

  Future<void> _confirmExit(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 36),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppTheme.backgroundGradient),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: AppTheme.bubbleDecoration(active: false),
                child: const Icon(Icons.logout_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              const Text("Exit to menu?",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                "Your current game progress will be lost.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                      child: _dialogButton("Cancel",
                          active: false,
                          onTap: () => Navigator.of(context).pop(false))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _dialogButton("Exit",
                          active: true,
                          onTap: () => Navigator.of(context).pop(true))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  ///A player's name chip + dice, floating outside the board above/below their home square
  ///(not overlapping the pawns). Chip sits closer to the screen edge, dice sits closer to the board.
  ///Must stay within the ancestor SizedBox's real bounds, since a RenderBox rejects hit-tests outside
  ///its own laid-out size even when a Stack's overflow is painted via `clipBehavior: Clip.none`.
  Widget _diceBadge(
      BuildContext context,
      LudoPlayerType type,
      Color color,
      bool isCpu,
      double boardSize,
      LudoPlayerType viewer,
      ({String name, String? photoBase64})? profile) {
    var (x, y) = LudoPath.viewCorner(type, viewer);
    double blockTop = y == 0
        ? _outerMargin
        : _topBand + boardSize + _gapToBoard + _bottomExtraPadding;

    var chip = _playerChip(color, isCpu, profile);
    var dice = SizedBox(
        width: _diceBadgeSize,
        height: _diceBadgeSize,
        child: DiceWidget(type: type));
    var gap = const SizedBox(height: _chipGap);

    return Positioned(
      top: blockTop,
      left: x == 0 ? boardSize * .08 : null,
      right: x == 1 ? boardSize * .08 : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: y == 0 ? [chip, gap, dice] : [dice, gap, chip],
      ),
    );
  }

  ///A player's avatar next to a name label, both inside one colored pill. Online games show
  ///the real synced name/photo (see [LudoProvider.onlineProfiles]); local games fall back to
  ///a grey placeholder circle with "Player"/"CPU".
  Widget _playerChip(
      Color color, bool isCpu, ({String name, String? photoBase64})? profile) {
    final name = profile?.name ?? (isCpu ? "CPU" : "Player");
    final photo = profile?.photoBase64;
    return Container(
      height: _chipHeight,
      padding: const EdgeInsets.only(
          left: _chipPadding,
          right: 10,
          top: _chipPadding,
          bottom: _chipPadding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_chipHeight / 2),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _avatarSize,
            height: _avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade400,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: photo == null
                ? Icon(isCpu ? Icons.smart_toy_rounded : Icons.person_rounded,
                    size: 26, color: Colors.grey.shade100)
                : ClipOval(
                    child: Image.memory(Uint8List.fromList(decodePhoto(photo)),
                        width: _avatarSize,
                        height: _avatarSize,
                        fit: BoxFit.cover),
                  ),
          ),
          const SizedBox(width: 6),
          Text(name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _dialogButton(String label,
      {required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: AppTheme.bubbleDecoration(
            active: active, borderRadius: BorderRadius.circular(24)),
        child: Text(label,
            style: TextStyle(
                color: active ? AppTheme.turquoiseDark : Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: AppTheme.backgroundGradient),
        ),
        child: Stack(
          children: [
            const Positioned.fill(child: WaveBackground()),
            const Positioned.fill(child: DiceRain()),
            Center(
              // BoardWidget adds its own `margin` on every side (for its shadow/rounded outer
              // corner), so its true footprint is bigger than `ludoBoard()` alone reports — this
              // box must span that full footprint or the board renders off-center (see `boardSize`).
              child: SizedBox(
                width: BoardWidget.ludoBoard(context) + BoardWidget.margin * 2,
                height: BoardWidget.ludoBoard(context) +
                    BoardWidget.margin * 2 +
                    _topBand +
                    _bottomBand,
                child: Consumer<LudoProvider>(
                  builder: (context, value, child) {
                    double boardSize =
                        BoardWidget.ludoBoard(context) + BoardWidget.margin * 2;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(
                            top: _topBand, left: 0, child: BoardWidget()),
                        ...value.activePlayerTypes.map(
                          (type) => _diceBadge(
                              context,
                              type,
                              value.player(type).color,
                              value.cpuTypes.contains(type),
                              boardSize,
                              value.viewerType,
                              value.onlineProfiles[type]),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => _confirmExit(context),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: AppTheme.bubbleDecoration(active: false),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
            Consumer<LudoProvider>(
              builder: (context, value, child) => value.winners.length ==
                      value.activePlayerTypes.length - 1
                  ? Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.8),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset("assets/images/thankyou.gif"),
                              const Text("Thank you for playing 😙",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 20),
                                  textAlign: TextAlign.center),
                              Text(
                                  "The Winners is: ${value.winners.map((e) => e.name.toUpperCase()).join(", ")}",
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 30),
                                  textAlign: TextAlign.center),
                              const Divider(color: Colors.white),
                              const Text(
                                  "This game made with Flutter ❤️ by Mochamad Nizwar Syafuan",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 15),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 20),
                              TextButton(
                                onPressed: () => Navigator.of(context)
                                    .popUntil((route) => route.isFirst),
                                child: const Text("Back to menu",
                                    style: TextStyle(
                                        color: Colors.white,
                                        decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
