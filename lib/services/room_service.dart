import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:ludo_flutter/constants.dart';
import 'package:ludo_flutter/ludo_provider.dart';

///One joined player as shown in the lobby list.
class RoomPlayer {
  final String uid;
  final String name;
  final String? photoBase64;
  final LudoPlayerType colorType;
  final bool connected;

  RoomPlayer(
      {required this.uid,
      required this.name,
      this.photoBase64,
      required this.colorType,
      required this.connected});

  factory RoomPlayer.fromMap(String uid, Map data) => RoomPlayer(
        uid: uid,
        name: (data['name'] as String?) ?? 'Player',
        photoBase64: data['photoBase64'] as String?,
        colorType: LudoPlayerType.values.byName(data['colorType'] as String),
        connected: data['connected'] as bool? ?? true,
      );
}

///Firebase Realtime Database-backed room: host/join, live lobby, and in-game state sync.
///See `database.rules.json` for the access rules this relies on.
class RoomService {
  static final _db = FirebaseDatabase.instance;
  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

  static String? get uid => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  static String _generateCode() {
    final rand = Random.secure();
    return List.generate(6, (_) => _codeChars[rand.nextInt(_codeChars.length)])
        .join();
  }

  ///Creates a room, joins the host as its first player (always green), and returns the code.
  static Future<String> hostRoom(
      {required int playerCount,
      required String name,
      String? photoBase64}) async {
    await ensureSignedIn();
    final myUid = uid!;
    String code;
    DatabaseReference ref;
    do {
      code = _generateCode();
      ref = _db.ref('rooms/$code');
    } while ((await ref.get()).exists);

    await ref.set({
      'hostUid': myUid,
      'status': 'lobby',
      'playerCount': playerCount,
      'createdAt': ServerValue.timestamp,
      'players': {
        myUid: {
          'name': name,
          if (photoBase64 != null) 'photoBase64': photoBase64,
          'colorType': LudoProvider.activeTypesFor(playerCount).first.name,
          'connected': true,
          'joinedAt': ServerValue.timestamp,
        },
      },
    });
    ref.child('players/$myUid/connected').onDisconnect().set(false);
    return code;
  }

  ///Joins an existing lobby, assigning the next unused color for that room's player count.
  ///Throws a plain [Exception] with a user-facing message on any failure to join.
  static Future<void> joinRoom(String code,
      {required String name, String? photoBase64}) async {
    await ensureSignedIn();
    final myUid = uid!;
    final ref = _db.ref('rooms/$code');
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      throw Exception('Room not found. Check the code and try again.');
    }

    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final players = Map<String, dynamic>.from((data['players'] as Map?) ?? {});
    if (players.containsKey(myUid)) {
      return; // already in this room (e.g. reconnect)
    }
    if (data['status'] != 'lobby') {
      throw Exception('This game has already started.');
    }

    final playerCount = data['playerCount'] as int;
    if (players.length >= playerCount) throw Exception('Room is full.');

    final usedColors =
        players.values.map((p) => (p as Map)['colorType'] as String).toSet();
    final myColor = LudoProvider.activeTypesFor(playerCount)
        .map((t) => t.name)
        .firstWhere((c) => !usedColors.contains(c));

    await ref.child('players/$myUid').set({
      'name': name,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      'colorType': myColor,
      'connected': true,
      'joinedAt': ServerValue.timestamp,
    });
    ref.child('players/$myUid/connected').onDisconnect().set(false);
  }

  ///My assigned color in this room, once joined.
  static Future<LudoPlayerType> myColorIn(String code) async {
    final snap = await _db.ref('rooms/$code/players/${uid!}/colorType').get();
    return LudoPlayerType.values.byName(snap.value as String);
  }

  static Stream<DatabaseEvent> watchRoom(String code) =>
      _db.ref('rooms/$code').onValue;

  static Stream<DatabaseEvent> watchGame(String code) =>
      _db.ref('rooms/$code/game').onValue;

  ///Host-only: seeds the shared game state and flips the room to "playing". Every device
  ///(including the host) picks this up through [watchGame] the same way, rather than the
  ///host special-casing its own local start.
  static Future<void> startGame(
      String code, List<LudoPlayerType> activeTypes) async {
    await _db.ref('rooms/$code').update({
      'status': 'playing',
      'game': {
        'currentTurn': activeTypes.first.name,
        'diceResult': 0,
        'gameState': LudoGameState.throwDice.name,
        'winners': <String>[],
        'lastWriterUid': '',
        'pawns': {for (final t in activeTypes) t.name: List.filled(4, -1)},
      },
    });
  }

  ///Pushes a locally-driven state change, tagged with our uid so our own [watchGame]
  ///listener knows to ignore the echo of its own write.
  static Future<void> pushGameState(
          String code, Map<String, dynamic> snapshot) =>
      _db.ref('rooms/$code/game').update({...snapshot, 'lastWriterUid': uid});

  static Future<void> leaveRoom(String code) async {
    final myUid = uid;
    if (myUid == null) return;
    await _db.ref('rooms/$code/players/$myUid').remove();
  }

  static Future<void> deleteRoom(String code) =>
      _db.ref('rooms/$code').remove();
}
