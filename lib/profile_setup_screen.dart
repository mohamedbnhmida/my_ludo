import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'constants.dart';
import 'host_join_screen.dart';
import 'services/profile_service.dart';
import 'widgets/wave_background.dart';

///Name + optional photo, shown once before the host/join flow. Pre-fills from whatever was
///saved last time (see [ProfileService]) so returning players don't retype it.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  String? _photoBase64;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.wait([ProfileService.loadName(), ProfileService.loadPhotoBase64()])
        .then((results) {
      setState(() {
        _nameController.text = results[0] ?? '';
        _photoBase64 = results[1];
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 60);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _photoBase64 = base64Encode(bytes));
  }

  void _continue() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    ProfileService.save(name: name, photoBase64: _photoBase64);
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HostJoinScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenBackground(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('YOUR PROFILE',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade400,
                                border:
                                    Border.all(color: Colors.white, width: 2)),
                            child: _photoBase64 == null
                                ? const Icon(Icons.person_rounded,
                                    size: 64, color: Colors.white)
                                : ClipOval(
                                    child: Image.memory(
                                        Uint8List.fromList(
                                            decodePhoto(_photoBase64!)),
                                        width: 110,
                                        height: 110,
                                        fit: BoxFit.cover)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration:
                                  AppTheme.bubbleDecoration(active: true),
                              child: const Icon(Icons.edit_rounded,
                                  size: 18, color: AppTheme.turquoiseDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _nameController,
                        maxLength: 20,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          counterText: '',
                          hintText: 'Your name',
                          hintStyle: TextStyle(color: Colors.white38),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white38)),
                          focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white)),
                        ),
                        onSubmitted: (_) => _continue(),
                      ),
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _loaded ? _continue : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 48, vertical: 18),
                        decoration: AppTheme.bubbleDecoration(
                            active: true,
                            borderRadius: BorderRadius.circular(36)),
                        child: const Text('CONTINUE',
                            style: TextStyle(
                                color: AppTheme.turquoiseDark,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
