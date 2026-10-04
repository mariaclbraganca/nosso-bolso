import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/compras_provider.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';

class ListaComprasTab extends ConsumerWidget {
  const ListaComprasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(listaComprasProvider(7));
    final checados = ref.watch(itensChecadosListaProvider);

    return listaAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: NBColors.verde)),
      error: (e, _) => Center(child: Text('Erro ao carregar lista: $e', style: const TextStyle(color: NBColors.estouro))),
      data: (dados) {
        final itens = (dados['itens'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        final totalPrevisto = (dados['custo_estimado_total'] as num?)?.toDouble() ?? 0.0;

        if (itens.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: UnicornVazio(
              type: UnicornType.geronimo,
              titulo: 'Sem compras planejadas',
              texto: 'Conforme você escaneia notas fiscais, a IA prevê os itens que estão acabando na despensa!',
            ),
          );
        }

        double totalCarrinho = 0.0;
        for (final item in itens) {
          final id = item['nome'] as String? ?? '';
          if (checados.contains(id)) {
            totalCarrinho += ((item['preco_estimado'] as num?)?.toDouble() ?? 0.0);
          }
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, 12, NBSpacing.margemTela, 120),
          children: [
            CartaoNB(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LISTA DE COMPRAS SUGERIDA (7 DIAS)', style: NBText.eyebrow),
                        const SizedBox(height: 4),
                        Text(
                          '${checados.length} de ${itens.length} itens no carrinho',
                          style: NBText.corpo.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('No carrinho', style: NBText.legenda),
                      Text(brl(totalCarrinho), style: NBText.valorCartao.copyWith(color: NBColors.verde, fontSize: 18)),
                      Text('Total est.: ${brl(totalPrevisto)}', style: NBText.legenda),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: NBSpacing.l),
            Row(
              children: [
                const Expanded(child: CabecalhoSecao(titulo: 'Itens Sugeridos pela IA')),
                if (checados.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(itensChecadosListaProvider.notifier).state = {},
                    child: const Text('Limpar carrinho', style: TextStyle(color: NBColors.tintaSuave)),
                  ),
              ],
            ),
            const SizedBox(height: NBSpacing.s),
            for (final item in itens) ...[
              _ItemListaCard(
                item: item,
                marcado: checados.contains(item['nome']),
                onToggle: () {
                  final nome = item['nome'] as String? ?? '';
                  final set = Set<String>.from(checados);
                  if (set.contains(nome)) {
                    set.remove(nome);
                  } else {
                    set.add(nome);
                  }
                  ref.read(itensChecadosListaProvider.notifier).state = set;
                },
              ),
              const SizedBox(height: 6),
            ],
          ],
        );
      },
    );
  }
}

class _ItemListaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool marcado;
  final VoidCallback onToggle;

  const _ItemListaCard({
    required this.item,
    required this.marcado,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final nome = item['nome'] as String? ?? 'Item';
    final preco = (item['preco_estimado'] as num?)?.toDouble() ?? 0.0;
    final motivo = item['motivo'] as String? ?? '';

    return CartaoNB(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        onTap: onToggle,
        child: Row(
          children: [
            Checkbox(
              value: marcado,
              activeColor: NBColors.verde,
              onChanged: (_) => onToggle(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: NBText.corpo.copyWith(
                      decoration: marcado ? TextDecoration.lineThrough : null,
                      color: marcado ? NBColors.tintaSuave : NBColors.tinta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (motivo.isNotEmpty)
                    Text(motivo, style: NBText.legenda),
                ],
              ),
            ),
            Text(
              brl(preco),
              style: NBText.valorCartao.copyWith(
                fontSize: 15,
                decoration: marcado ? TextDecoration.lineThrough : null,
                color: marcado ? NBColors.tintaSuave : NBColors.tinta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
