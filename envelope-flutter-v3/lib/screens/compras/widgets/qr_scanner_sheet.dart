import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

class QrScannerSheet extends StatefulWidget {
  final ValueChanged<String> onCodeScanned;

  const QrScannerSheet({super.key, required this.onCodeScanned});

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  final MobileScannerController _controller = MobileScannerController();
  bool _processado = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processado) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.startsWith('http')) {
        _processado = true;
        widget.onCodeScanned(code);
        Navigator.pop(context);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: NBColors.papel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: TopoSheet(
              titulo: 'Escanear QR Code da NFC-e',
              subtitulo: 'Aponte a câmera para o QR Code impresso no cupom fiscal',
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(color: NBColors.verde, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.flash_on_rounded, color: NBColors.tinta),
                    onPressed: () => _controller.toggleTorch(),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    icon: const Icon(Icons.cameraswitch_rounded, color: NBColors.tinta),
                    onPressed: () => _controller.switchCamera(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
