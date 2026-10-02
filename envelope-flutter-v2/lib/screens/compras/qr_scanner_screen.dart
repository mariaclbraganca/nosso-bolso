import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import 'widgets/qr_scanner_dialogs.dart';
import 'widgets/qr_scanner_overlay.dart';

/// Fullscreen scanner para QR code de NFC-e.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _processado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _isLikelyNfce(String raw) {
    final lower = raw.toLowerCase();
    return lower.contains('nfce') ||
        lower.contains('sefaz') ||
        lower.contains('fazenda') ||
        lower.contains('receita') ||
        lower.contains('gov.br') ||
        lower.contains('encat') ||
        lower.contains('chnfe') ||
        lower.contains('p=');
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processado) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    if (!_isLikelyNfce(raw)) {
      final aceitar = await confirmarEnvioGenerico(context, raw);
      if (aceitar && mounted) _concluir(raw);
      return;
    }

    _concluir(raw);
  }

  void _concluir(String url) {
    _processado = true;
    _controller.stop();
    Navigator.of(context).pop(url);
  }

  Future<void> _digitarManualmente() async {
    final url = await abrirDialogDigitarManualmente(context);
    if (url != null && url.isNotEmpty && mounted) {
      _concluir(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Text('Escanear NFC-e', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.acc),
            onPressed: _digitarManualmente,
            tooltip: 'Digitar manualmente',
          ),
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: state.torchState == TorchState.on ? AppColors.gold : Colors.white,
              ),
            ),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Lanterna',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Trocar câmera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          ColorFiltered(
            colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.55), BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.acc, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: const [
                  Positioned(top: -1, left: -1, child: QrCorner(Alignment.topLeft)),
                  Positioned(top: -1, right: -1, child: QrCorner(Alignment.topRight)),
                  Positioned(bottom: -1, left: -1, child: QrCorner(Alignment.bottomLeft)),
                  Positioned(bottom: -1, right: -1, child: QrCorner(Alignment.bottomRight)),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Aponte para o QR code da nota fiscal', style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('NFC-e de qualquer SEFAZ ou Estado', style: TextStyle(color: AppColors.acc, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
