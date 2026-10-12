import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../constants.dart';

///Full-screen camera scanner; pops with the decoded text as soon as a QR code is read.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) return;
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: AppTheme.bubbleDecoration(active: false),
                  child: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 48),
              child: Text(
                'Point the camera at the room QR code',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
