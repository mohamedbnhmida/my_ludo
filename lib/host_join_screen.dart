import 'package:flutter/material.dart';

import 'constants.dart';
import 'lobby_screen.dart';
import 'services/profile_service.dart';
import 'services/room_service.dart';
import 'widgets/qr_scan_screen.dart';
import 'widgets/wave_background.dart';

///"Host a game" (pick a player count, get a room code) or "Join a game" (type a code),
///both leading into [LobbyScreen].
class HostJoinScreen extends StatefulWidget {
  const HostJoinScreen({super.key});

  @override
  State<HostJoinScreen> createState() => _HostJoinScreenState();
}

class _HostJoinScreenState extends State<HostJoinScreen> {
  int _playerCount = 4;
  final _codeController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<(String name, String? photo)> _profile() async {
    final name = await ProfileService.loadName();
    final photo = await ProfileService.loadPhotoBase64();
    return (name ?? 'Player', photo);
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    if (code == null || !mounted) return;
    _codeController.text = code.trim().toUpperCase();
    _join();
  }

  Future<void> _host() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (name, photo) = await _profile();
      final code = await RoomService.hostRoom(
          playerCount: _playerCount, name: name, photoBase64: photo);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LobbyScreen(code: code, isHost: true)));
    } catch (e) {
      setState(() => _error =
          'Could not create room. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-character code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (name, photo) = await _profile();
      await RoomService.joinRoom(code, name: name, photoBase64: photo);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LobbyScreen(code: code, isHost: false)));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenBackground(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                    width: 44,
                    height: 44,
                    decoration: AppTheme.bubbleDecoration(active: false),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white)),
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('HOST A GAME',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [2, 3, 4].map((n) {
                          final selected = n == _playerCount;
                          return GestureDetector(
                            onTap: () => setState(() => _playerCount = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              width: 52,
                              height: 52,
                              decoration:
                                  AppTheme.bubbleDecoration(active: selected),
                              alignment: Alignment.center,
                              child: Text('$n',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: selected
                                          ? AppTheme.turquoiseDark
                                          : Colors.white)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: _busy ? null : _host,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: AppTheme.bubbleDecoration(
                              active: true,
                              borderRadius: BorderRadius.circular(28)),
                          child: const Text('CREATE ROOM',
                              style: TextStyle(
                                  color: AppTheme.turquoiseDark,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Row(children: [
                        Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.3))),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('OR',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontWeight: FontWeight.bold))),
                        Expanded(
                            child: Divider(
                                color: Colors.white.withValues(alpha: 0.3))),
                      ]),
                      const SizedBox(height: 36),
                      const Text('JOIN A GAME',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: 'CODE',
                          hintStyle: const TextStyle(color: Colors.white38, letterSpacing: 6),
                          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          suffixIcon: IconButton(
                            onPressed: _scanQr,
                            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white70),
                            tooltip: 'Scan QR code',
                          ),
                        ),
                        onSubmitted: (_) => _join(),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _busy ? null : _join,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          alignment: Alignment.center,
                          decoration: AppTheme.bubbleDecoration(
                              active: false,
                              borderRadius: BorderRadius.circular(28)),
                          child: const Text('JOIN ROOM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.orangeAccent, fontSize: 13)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
