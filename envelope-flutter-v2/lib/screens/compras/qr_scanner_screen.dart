import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';

/// Fullscreen scanner para QR code de NFC-e.
/// Retorna a URL detectada via Navigator.pop, ou null se cancelado.
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

  void _onDetect(BarcodeCapture capture) {
    if (_processado) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    final lower = raw.toLowerCase();
    if (!lower.contains('nfce') && !lower.contains('sefaz')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'QR não parece NFC-e: ${raw.substring(0, raw.length.clamp(0, 60))}…'),
        backgroundColor: AppColors.org,
      ));
      return;
    }

    _processado = true;
    _controller.stop();
    Navigator.of(context).pop(raw);
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
        title: const Text(
          'Escanear NFC-e',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder<MobileScannerState>(
              valueListenable: _controller,
              builder: (_, state, __) => Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                color: state.torchState == TorchState.on
                    ? AppColors.gold
                    : Colors.white,
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

          // Fundo escurecido com janela central
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.srcOut,
            ),
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
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Borda verde na janela
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

          // Cantos decorativos
          Center(
            child: SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                children: [
                  // canto superior esquerdo
                  Positioned(
                    top: -1, left: -1,
                    child: _Corner(Alignment.topLeft),
                  ),
                  // canto superior direito
                  Positioned(
                    top: -1, right: -1,
                    child: _Corner(Alignment.topRight),
                  ),
                  // canto inferior esquerdo
                  Positioned(
                    bottom: -1, left: -1,
                    child: _Corner(Alignment.bottomLeft),
                  ),
                  // canto inferior direito
                  Positioned(
                    bottom: -1, right: -1,
                    child: _Corner(Alignment.bottomRight),
                  ),
                ],
              ),
            ),
          ),

          // Instrução
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Aponte para o QR code da nota fiscal',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'NFC-e / SEFAZ',
                      style: TextStyle(
                          color: AppColors.acc,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
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

class _Corner extends StatelessWidget {
  final Alignment alignment;
  const _Corner(this.alignment);

  @override
  Widget build(BuildContext context) {
    final isTop = alignment == Alignment.topLeft || alignment == Alignment.topRight;
    final isLeft = alignment == Alignment.topLeft || alignment == Alignment.bottomLeft;

    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(
        painter: _CornerPainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  const _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.acc
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final x = isLeft ? 0.0 : size.width;
    final y = isTop ? 0.0 : size.height;
    final dx = isLeft ? size.width : -size.width;
    final dy = isTop ? size.height : -size.height;

    canvas.drawLine(Offset(x, y), Offset(x + dx, y), paint);
    canvas.drawLine(Offset(x, y), Offset(x, y + dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
