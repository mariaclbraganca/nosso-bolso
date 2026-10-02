import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

class ComprasHeader extends StatelessWidget {
  final int pendentesCount;
  final VoidCallback onEscanear;
  final VoidCallback onColarUrl;

  const ComprasHeader({
    super.key,
    required this.pendentesCount,
    required this.onEscanear,
    required this.onColarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const UnicornWidget(type: UnicornType.geronimo, size: 36, animate: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LEITOR INTELIGENTE NFC-e', style: NBText.eyebrow),
                    const SizedBox(height: 2),
                    Text(
                      pendentesCount > 0
                          ? '$pendentesCount ${pendentesCount == 1 ? 'nota aguardando' : 'notas aguardando'} confirmação'
                          : 'Todas as notas estão confirmadas',
                      style: NBText.corpo.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (pendentesCount > 0)
                SeloNB('$pendentesCount PENDENTE', cor: NBColors.estouro, fundo: NBColors.estouroClaro),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEscanear,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Escanear QR'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onColarUrl,
                icon: const Icon(Icons.link_rounded, size: 18),
                label: const Text('Colar URL'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NBColors.tinta,
                  side: const BorderSide(color: NBColors.linha),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
