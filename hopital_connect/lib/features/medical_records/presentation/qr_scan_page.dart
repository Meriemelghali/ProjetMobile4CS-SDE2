import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'emergency_card_page.dart';
import 'widgets/record_ui.dart';

/// Scanne la carte d'urgence d'un patient et renvoie son identifiant.
class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    _sweep.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final patientId = patientIdFromQr(raw);
      if (patientId != null) {
        _done = true;
        Navigator.pop(context, patientId);
        return;
      }
      setState(() => _hint = 'Ce QR code n’est pas une carte HôpitalConnect.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('Scanner une carte d’urgence'),
      actions: [
        IconButton(
          tooltip: 'Lampe',
          onPressed: _controller.toggleTorch,
          icon: const Icon(Icons.flashlight_on_outlined),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Caméra indisponible : ${error.errorDetails?.message ?? error.errorCode.name}.\n'
                'Autorisez l’accès à la caméra ou recherchez le patient par son nom.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) => Positioned(
                    left: 16,
                    right: 16,
                    top: 16 + _sweep.value * 214,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(color: RecordColors.normal, blurRadius: 12),
                        ],
                        color: RecordColors.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 40,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _hint ?? 'Placez le QR code de la carte d’urgence dans le cadre.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
