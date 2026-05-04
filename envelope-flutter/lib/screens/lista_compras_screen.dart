import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/compras_provider.dart';

class ListaComprasScreen extends ConsumerStatefulWidget {
  const ListaComprasScreen({super.key});

  @override
  ConsumerState<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends ConsumerState<ListaComprasScreen> {
  int _dias = 15;

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(listaComprasProvider(_dias));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Lista Inteligente'),
        actions: [
          DropdownButton<int>(
            value: _dias,
            dropdownColor: AppColors.surf,
            underline: const SizedBox(),
            icon: const Icon(Icons.calendar_today_outlined,
                color: AppColors.mu, size: 18),
            items: [7, 15, 30]
                .map((d) => DropdownMenuItem<int>(
                      value: d,
                      child: Text('$d dias',
                          style: const TextStyle(color: AppColors.tx)),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _dias = v ?? 15),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: listaAsync.when(
        data: (lista) {
          if (lista.isEmpty) {
            return const Center(
              child: Text(
                'Sem dados. Configure o perfil da família.',
                style: TextStyle(color: AppColors.mu),
              ),
            );
          }
          final itens = (lista['itens'] as List?) ?? [];
          final total = (lista['custo_estimado_total'] as num?)
                  ?.toStringAsFixed(2) ??
              '0.00';
          final saldo =
              (lista['saldo_envelope'] as num?)?.toStringAsFixed(2) ?? '0.00';
          final dentro = lista['dentro_do_orcamento'] as bool? ?? true;
          return Column(children: [
            _ResumoCard(
              total: total,
              saldo: saldo,
              dentro: dentro,
              dias: lista['dias_cobertura'] as int? ?? _dias,
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: itens.length,
                itemBuilder: (ctx, i) => _ItemListaCard(
                  item: Map<String, dynamic>.from(itens[i]),
                ),
              ),
            ),
          ]);
        },
        loading: () => const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: AppColors.acc),
            SizedBox(height: 12),
            Text(
              'Gerando lista inteligente com IA…',
              style: TextStyle(color: AppColors.mu, fontSize: 13),
            ),
          ]),
        ),
        error: (e, _) => Center(
          child: Text('Erro: $e', style: const TextStyle(color: AppColors.red)),
        ),
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String total;
  final String saldo;
  final bool dentro;
  final int dias;
  const _ResumoCard(
      {required this.total,
      required this.saldo,
      required this.dentro,
      required this.dias});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: dentro
              ? AppColors.acc.withAlpha(102)
              : AppColors.red.withAlpha(102),
        ),
      ),
      child: Row(children: [
        Icon(
          dentro ? Icons.check_circle : Icons.warning_amber_rounded,
          color: dentro ? AppColors.acc : AppColors.red,
          size: 32,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Lista para $dias dias',
                style: const TextStyle(color: AppColors.mu, fontSize: 12)),
            Text(
              'Estimado: R\$ $total',
              style: TextStyle(
                  color: dentro ? AppColors.acc : AppColors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            Text('Saldo envelope: R\$ $saldo',
                style: const TextStyle(color: AppColors.mu, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}

class _ItemListaCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ItemListaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final corte = item['corte_sugerido'] as bool? ?? false;
    return Opacity(
      opacity: corte ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: corte ? AppColors.red.withAlpha(76) : AppColors.bord,
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['nome'] ?? '',
                    style: TextStyle(
                      color: corte ? AppColors.mu : AppColors.tx,
                      fontSize: 14,
                      decoration:
                          corte ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item['quantidade_sugerida']} ${item['unidade']} · ${item['categoria']}',
                    style: const TextStyle(color: AppColors.mu, fontSize: 11),
                  ),
                  if ((item['motivo'] as String? ?? '').isNotEmpty)
                    Text(item['motivo'] as String,
                        style: const TextStyle(
                            color: AppColors.mu, fontSize: 10)),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              'R\$ ${(item['preco_estimado'] as num).toStringAsFixed(2)}',
              style: const TextStyle(
                  color: AppColors.acc, fontWeight: FontWeight.bold),
            ),
            if (corte)
              const Text('Corte sugerido',
                  style: TextStyle(color: AppColors.red, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}
