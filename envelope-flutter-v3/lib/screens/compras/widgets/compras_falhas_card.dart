import 'package:flutter/material.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';

/// Notas que falharam ao processar, com a dica do motivo e as ações de
/// tentar de novo (mesma URL) ou dispensar.
class ComprasFalhasCard extends StatelessWidget {
  const ComprasFalhasCard({
    super.key,
    required this.falhas,
    required this.onTentarDeNovo,
    required this.onDispensar,
  });

  final List<Map<String, dynamic>> falhas;
  final ValueChanged<String> onTentarDeNovo;
  final VoidCallback onDispensar;

  static String dicaPara(String? categoria) => switch (categoria) {
        'sefaz' => 'O portal da SEFAZ está instável. Tente de novo em alguns minutos.',
        'ia' => 'A IA recusou a leitura (cota ou chave). Confira em Configurações > Inteligência artificial.',
        _ => 'Tente de novo. Se continuar, confira a internet.',
      };

  @override
  Widget build(BuildContext context) {
    final primeira = falhas.first;
    final erro = (primeira['erro'] as String?) ?? 'Erro desconhecido';
    final url = primeira['qr_code_url'] as String?;
    final n = falhas.length;

    return CartaoNB(
      borda: NBColors.estouro,
      cor: NBColors.estouroClaro,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: NBColors.estouro, size: 20),
              const SizedBox(width: NBSpacing.s),
              Expanded(
                child: Text(
                  n == 1 ? '1 nota não foi lida' : '$n notas não foram lidas',
                  style: NBText.rotulo.copyWith(color: NBColors.estouro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(dicaPara(primeira['erro_categoria'] as String?), style: NBText.corpo.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(erro.length > 120 ? '${erro.substring(0, 120)}…' : erro, style: NBText.legenda),
          const SizedBox(height: NBSpacing.m),
          Row(
            children: [
              if (url != null)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onTentarDeNovo(url),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Tentar de novo'),
                  ),
                ),
              if (url != null) const SizedBox(width: NBSpacing.s),
              TextButton(
                onPressed: onDispensar,
                child: const Text('Dispensar', style: TextStyle(color: NBColors.estouro)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
