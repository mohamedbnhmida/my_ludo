import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'constants.dart';
import 'ludo_provider.dart';
import 'main_screen.dart';
import 'services/profile_service.dart';
import 'services/room_service.dart';
import 'widgets/wave_background.dart';

///Waiting room for one code: shows the code + QR + share button, a live player list, and
///(host only) a "Start" button. Owns the online game's Firebase subscriptions for as long as
///it's on the navigation stack — including while [MainScreen] is pushed on top of it — and
///tears the room down in [dispose], which only fires once the whole online flow is popped.
class LobbyScreen extends StatefulWidget {
  final String code;
  final bool isHost;
  const LobbyScreen({super.key, required this.code, required this.isHost});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  StreamSubscription<DatabaseEvent>? _roomSub;
  StreamSubscription<DatabaseEvent>? _gameSub;
  List<RoomPlayer> _players = [];
  int _playerCount = 4;
  bool _navigatedToGame = false;
  bool _starting = false;

  /// Who was actually in the match the moment it started — if any of them disappears from
  /// `players` later (or the room itself disappears), the match can't continue, so everyone
  /// still around exits too instead of being left stuck on a frozen board.
  Set<String> _matchUids = {};

  @override
  void initState() {
    super.initState();
    _roomSub = RoomService.watchRoom(widget.code).listen(_onRoomEvent);
  }

  void _exitToMenu() {
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _onRoomEvent(DatabaseEvent event) {
    final raw = event.snapshot.value;
    if (raw == null) {
      // Room is gone — host left (or cancelled before starting). Nobody left in it can continue.
      _exitToMenu();
      return;
    }
    final data = Map<String, dynamic>.from(raw as Map);
    final playersRaw =
        Map<String, dynamic>.from((data['players'] as Map?) ?? {});
    setState(() {
      _playerCount = data['playerCount'] as int? ?? 4;
      _players = playersRaw.entries
          .map((e) => RoomPlayer.fromMap(
              e.key, Map<String, dynamic>.from(e.value as Map)))
          .toList()
        ..sort((a, b) => a.colorType.index.compareTo(b.colorType.index));
    });
    if (data['status'] == 'playing' && !_navigatedToGame) {
      _navigatedToGame = true;
      _matchUids = playersRaw.keys.toSet();
      _enterMatch(LudoProvider.activeTypesFor(_playerCount));
    } else if (_navigatedToGame && !_matchUids.every(playersRaw.containsKey)) {
      // Someone who was actually in the match left mid-game — end it for whoever's left.
      _exitToMenu();
    }
  }

  ///Wires the local [LudoProvider] into the room's shared game state and pushes [MainScreen].
  ///Every device does this the same way — host included — once `status` flips to "playing".
  Future<void> _enterMatch(List<LudoPlayerType> activeTypes) async {
    final myColor = await RoomService.myColorIn(widget.code);
    if (!mounted) return;
    final provider = Provider.of<LudoProvider>(context, listen: false);
    provider.startOnlineGame(activeTypes: activeTypes, viewer: myColor);
    provider.onlineProfiles = {
      for (final p in _players)
        p.colorType: (name: p.name, photoBase64: p.photoBase64),
    };
    provider.onGameChanged =
        (snapshot) => RoomService.pushGameState(widget.code, snapshot);
    _gameSub = RoomService.watchGame(widget.code).listen((event) {
      final raw = event.snapshot.value;
      if (raw == null) return;
      final data = Map<String, dynamic>.from(raw as Map);
      if (data['lastWriterUid'] == RoomService.uid) {
        return; // ignore the echo of our own write
      }
      provider.applyRemoteSnapshot(data);
    });
    if (!mounted) return;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MainScreen()));
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    await RoomService.startGame(
        widget.code, LudoProvider.activeTypesFor(_playerCount));
    // No local navigation here — the room listener above picks up status == "playing"
    // and calls _enterMatch for every device, host included, so everyone starts in sync.
  }

  void _share() => SharePlus.instance
      .share(ShareParams(text: 'Join my MyLudo game! Code: ${widget.code}'));

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Code copied'), duration: Duration(seconds: 1)));
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _gameSub?.cancel();
    if (widget.isHost) {
      RoomService.deleteRoom(
          widget.code); // no host migration — leaving as host ends the room
    } else {
      RoomService.leaveRoom(widget.code);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canStart =
        widget.isHost && !_starting && _players.length == _playerCount;
    return ScreenBackground(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: AppTheme.bubbleDecoration(active: false),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: Colors.white)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _share,
                  child: Container(
                      width: 44,
                      height: 44,
                      decoration: AppTheme.bubbleDecoration(active: false),
                      child: const Icon(Icons.share_rounded,
                          color: Colors.white, size: 20)),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('ROOM CODE',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.code,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8)),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: _copyCode,
                          icon: const Icon(Icons.copy_rounded,
                              color: Colors.white70, size: 22),
                          tooltip: 'Copy code',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16)),
                      child: QrImageView(
                          data: widget.code,
                          size: 160,
                          backgroundColor: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    Text('PLAYERS  ${_players.length}/$_playerCount',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ..._players.map(_playerRow),
                    const SizedBox(height: 32),
                    if (widget.isHost)
                      GestureDetector(
                        onTap: canStart ? _start : null,
                        child: Opacity(
                          opacity: canStart ? 1 : 0.4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 48, vertical: 18),
                            decoration: AppTheme.bubbleDecoration(
                                active: true,
                                borderRadius: BorderRadius.circular(36)),
                            child: Text(_starting ? 'STARTING…' : 'START GAME',
                                style: const TextStyle(
                                    color: AppTheme.turquoiseDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2)),
                          ),
                        ),
                      )
                    else
                      const Text('Waiting for the host to start…',
                          style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerRow(RoomPlayer p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade400,
                border: Border.all(color: LudoColor.of(p.colorType), width: 2)),
            child: p.photoBase64 == null
                ? const Icon(Icons.person_rounded,
                    color: Colors.white, size: 22)
                : ClipOval(
                    child: Image.memory(
                        Uint8List.fromList(decodePhoto(p.photoBase64!)),
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover)),
          ),
          const SizedBox(width: 10),
          Text(p.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
