import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../providers/saude_provider.dart';
import '../../providers/usuarios_provider.dart';
import '../../services/saude_api_service.dart';
import 'anamnese_screen.dart';

class PerfilMetabolicoScreen extends ConsumerWidget {
  final String membroId;

  const PerfilMetabolicoScreen({super.key, required this.membroId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfilAsync = ref.watch(perfilMetabolicoProvider(membroId));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: perfilAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.grn)),
          error: (e, _) => Center(child: Text('Erro: $e', style: const TextStyle(color: AppColors.red))),
          data: (perfil) => perfil == null
              ? _SemPerfilPrompt(membroId: membroId)
              : _PerfilContent(membroId: membroId, perfil: perfil, ref: ref),
        ),
      ),
    );
  }
}

class _SemPerfilPrompt extends StatelessWidget {
  final String membroId;
  const _SemPerfilPrompt({required this.membroId});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🥗', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('Vamos montar seu plano!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.tx)),
            const SizedBox(height: 8),
            const Text('Responda algumas perguntas rápidas e vou calcular quantas calorias e proteínas você precisa por dia.', style: TextStyle(color: AppColors.mu, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.grn, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnamneseScreen(membroId: membroId))),
              child: const Text('Criar meu plano', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PerfilContent extends StatefulWidget {
  final String membroId;
  final Map<String, dynamic> perfil;
  final WidgetRef ref;

  const _PerfilContent({required this.membroId, required this.perfil, required this.ref});

  @override
  State<_PerfilContent> createState() => _PerfilContentState();
}

class _PerfilContentState extends State<_PerfilContent> {
  @override
  Widget build(BuildContext context) {
    final met = widget.perfil['metabolico'] as Map<String, dynamic>? ?? {};
    final macros = met['metas_macros'] as Map<String, dynamic>? ?? {};
    final antro = widget.perfil['antropometria'] as Map<String, dynamic>? ?? {};
    final anamnese = widget.perfil['anamnese'] as Map<String, dynamic>? ?? {};
    final suplementos = (anamnese['suplementos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final alergias = (anamnese['alergias'] as List?)?.cast<String>() ?? [];
    final pausas = (widget.perfil['pausas'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final objetivoLabel = {
      'perda_peso': '⬇️ Perda de Peso',
      'manutencao': '↔️ Manutenção',
      'ganho_massa': '⬆️ Ganho de Massa',
    }[met['objetivo'] ?? 'manutencao'] ?? 'Manutenção';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(objetivoLabel, antro)),
        SliverToBoxAdapter(child: _buildMetabolico(met, macros)),
        SliverToBoxAdapter(child: _buildAntropometria(antro)),
        if (suplementos.isNotEmpty) SliverToBoxAdapter(child: _buildSuplemmentos(suplementos)),
        if (alergias.isNotEmpty) SliverToBoxAdapter(child: _buildAlergias(alergias)),
        SliverToBoxAdapter(child: _buildProgresso(context)),
        SliverToBoxAdapter(child: _buildPausa(context, pausas)),
        SliverToBoxAdapter(child: _buildAcoes(context)),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildHeader(String objetivo, Map<String, dynamic> antro) {
    final nome = (widget.perfil['anamnese'] as Map<String, dynamic>?)?['nome_curto'] as String? ?? 'Membro';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.grn.withOpacity(0.2),
            child: Text(nome[0].toUpperCase(), style: const TextStyle(color: AppColors.grn, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Perfil Nutricional', style: TextStyle(fontSize: 12, color: AppColors.mu)),
              Text(objetivo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.tx)),
              Text(
                '${(antro['peso_kg'] as num?)?.toStringAsFixed(1) ?? '?'}kg  •  ${(antro['altura_cm'] as num?)?.toInt() ?? '?'}cm  •  ${antro['idade'] ?? '?'} anos',
                style: const TextStyle(fontSize: 12, color: AppColors.mu),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetabolico(Map<String, dynamic> met, Map<String, dynamic> macros) {
    final tmb = (met['tmb_kcal'] as num?)?.toInt() ?? 0;
    final tdee = (met['tdee_kcal'] as num?)?.toInt() ?? 0;
    final meta = (met['meta_calorica_kcal'] as num?)?.toInt() ?? 0;
    final protComida = (macros['proteina_via_comida_g'] as num?)?.toInt() ?? 0;
    final carb = (macros['carboidrato_g'] as num?)?.toInt() ?? 0;
    final gord = (macros['gordura_g'] as num?)?.toInt() ?? 0;

    return _Secao(
      titulo: 'SEU PLANO DIÁRIO',
      children: [
        _InfoRow('Calorias que você queima em repouso', '$tmb kcal'),
        _InfoRow('Calorias que você gasta no dia a dia', '$tdee kcal'),
        _InfoRow('Sua meta calórica diária', '$meta kcal', destaque: true),
        const Divider(color: AppColors.bord, height: 16),
        _InfoRow('Proteína (via alimentação)', '${protComida}g', destaque: true),
        _InfoRow('Carboidrato', '${carb}g'),
        _InfoRow('Gordura', '${gord}g'),
      ],
    );
  }

  Widget _buildAntropometria(Map<String, dynamic> antro) {
    final pctGordura = antro['percentual_gordura'];
    final massaMagra = antro['massa_magra_kg'];

    return _Secao(
      titulo: 'Composição Corporal',
      trailing: TextButton.icon(
        icon: const Icon(Icons.add_rounded, size: 14, color: AppColors.grn),
        label: const Text('Registrar Peso', style: TextStyle(fontSize: 12, color: AppColors.grn)),
        onPressed: () => _registrarPeso(context),
      ),
      children: [
        _InfoRow('Peso Atual', '${(antro['peso_kg'] as num?)?.toStringAsFixed(1) ?? '?'}kg'),
        if (pctGordura != null) _InfoRow('% Gordura', '${(pctGordura as num).toStringAsFixed(1)}%'),
        if (massaMagra != null) _InfoRow('Massa Magra', '${(massaMagra as num).toStringAsFixed(1)}kg'),
        _InfoRow('Última Medição', _formatarData(antro['ultima_medicao'] as String?)),
      ],
    );
  }

  Widget _buildSuplemmentos(List<Map<String, dynamic>> suplementos) {
    return _Secao(
      titulo: 'Suplementação',
      children: suplementos.map((s) => _InfoRow(
        s['nome'] as String? ?? '',
        s['dose'] as String? ?? '',
      )).toList(),
    );
  }

  Widget _buildAlergias(List<String> alergias) {
    return _Secao(
      titulo: 'Restrições Alimentares',
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: alergias.map((a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.red.withOpacity(0.3)),
            ),
            child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.red)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildProgresso(BuildContext context) {
    return _Secao(
      titulo: 'Progresso Corporal',
      children: [
        const Text('Registre fotos mensais para acompanhar sua evolução.', style: TextStyle(fontSize: 12, color: AppColors.mu)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.grn,
            side: const BorderSide(color: AppColors.grn),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.add_a_photo_rounded, size: 18),
          label: const Text('Nova Foto de Progresso'),
          onPressed: () => _adicionarFotoProgresso(context),
        ),
      ],
    );
  }

  Widget _buildPausa(BuildContext context, List<Map<String, dynamic>> pausas) {
    return _Secao(
      titulo: 'Pausar Monitoramento',
      children: [
        const Text('Férias, doença ou evento especial? Pause o monitoramento para não distorcer seu relatório.', style: TextStyle(fontSize: 12, color: AppColors.mu)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.org,
            side: const BorderSide(color: AppColors.org),
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.beach_access_rounded, size: 18),
          label: const Text('🏖️ Pausar Monitoramento'),
          onPressed: () => _adicionarPausa(context),
        ),
      ],
    );
  }

  Widget _buildAcoes(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(children: [
        const Text(
          'Seus dados mudaram? Refaça o plano para atualizar suas metas.',
          style: TextStyle(fontSize: 12, color: AppColors.mu),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.grn,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refazer Meu Plano', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AnamneseScreen(membroId: widget.membroId)),
          ),
        ),
      ]),
    );
  }

  String _formatarData(String? isoDate) {
    if (isoDate == null) return '—';
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return isoDate.split('T').first;
    }
  }

  void _registrarPeso(BuildContext context) {
    final ctrl = TextEditingController();
    final familiaId = widget.ref.read(perfilUsuarioLogadoProvider).asData?.value?['familia_id'] as String? ?? '';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Registrar Peso', style: TextStyle(color: AppColors.tx)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: AppColors.tx),
          decoration: const InputDecoration(hintText: '74.5', suffixText: 'kg', hintStyle: TextStyle(color: AppColors.mu), suffixStyle: TextStyle(color: AppColors.mu)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.grn),
            onPressed: () async {
              final peso = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (peso == null) return;
              Navigator.pop(context);
              try {
                final now = DateTime.now();
                await SaudeApiService.registrarPeso({
                  'membro_id': widget.membroId,
                  'familia_id': familiaId,
                  'peso_kg': peso,
                  'data_medicao': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                });
                widget.ref.invalidate(perfilMetabolicoProvider);
                widget.ref.invalidate(historicoPesoProvider);
              } catch (_) {}
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _adicionarFotoProgresso(BuildContext context) async {
    final angulo = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Ângulo da foto', style: TextStyle(color: AppColors.tx)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['frente', 'costas', 'lateral'].map((a) => ListTile(
            title: Text(a[0].toUpperCase() + a.substring(1), style: const TextStyle(color: AppColors.tx)),
            onTap: () => Navigator.pop(context, a),
          )).toList(),
        ),
      ),
    );
    if (angulo == null || !mounted) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (file == null || !mounted) return;

    final familiaId = widget.ref.read(perfilUsuarioLogadoProvider).asData?.value?['familia_id'] as String? ?? '';
    try {
      final bytes = await file.readAsBytes();
      final base64img = base64Encode(bytes);
      final now = DateTime.now();
      await SaudeApiService.registrarProgressoFisico({
        'membro_id': widget.membroId,
        'familia_id': familiaId,
        'angulo': angulo,
        'imagem_base64': base64img,
        'mime_type': 'image/jpeg',
        'mes_referencia': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de progresso salva!'), backgroundColor: AppColors.grn),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  void _adicionarPausa(BuildContext context) {
    DateTime? inicio;
    DateTime? fim;
    String motivoSelecionado = 'ferias';

    String fmtDate(DateTime? dt) => dt == null
        ? 'Selecionar'
        : '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pickDate(bool isInicio) async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: isInicio ? now : (inicio ?? now).add(const Duration(days: 1)),
              firstDate: now.subtract(const Duration(days: 30)),
              lastDate: now.add(const Duration(days: 365)),
            );
            if (picked != null) setLocal(() => isInicio ? inicio = picked : fim = picked);
          }

          return AlertDialog(
            backgroundColor: AppColors.card,
            title: const Text('🏖️ Pausar Monitoramento', style: TextStyle(color: AppColors.tx)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Em quais datas você quer pausar?', style: TextStyle(color: AppColors.mu, fontSize: 12)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _DatePickerTile(
                    label: 'Início',
                    value: fmtDate(inicio),
                    onTap: () => pickDate(true),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _DatePickerTile(
                    label: 'Fim',
                    value: fmtDate(fim),
                    onTap: () => pickDate(false),
                  )),
                ]),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: motivoSelecionado,
                  isExpanded: true,
                  dropdownColor: AppColors.surf,
                  style: const TextStyle(color: AppColors.tx),
                  underline: const Divider(color: AppColors.bord),
                  items: const [
                    DropdownMenuItem(value: 'ferias', child: Text('🏖️ Férias')),
                    DropdownMenuItem(value: 'doenca', child: Text('🤒 Doença')),
                    DropdownMenuItem(value: 'evento_especial', child: Text('🎉 Evento Especial')),
                    DropdownMenuItem(value: 'outro', child: Text('📌 Outro motivo')),
                  ],
                  onChanged: (v) => setLocal(() => motivoSelecionado = v ?? 'ferias'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.org),
                onPressed: inicio == null || fim == null
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        String isoDate(DateTime dt) =>
                            '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
                        try {
                          await SaudeApiService.atualizarPerfilMetabolico(widget.membroId, {
                            'nova_pausa': {
                              'inicio': isoDate(inicio!),
                              'fim': isoDate(fim!),
                              'motivo': motivoSelecionado,
                            },
                          });
                          widget.ref.invalidate(perfilMetabolicoProvider);
                        } catch (_) {}
                      },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  final List<Widget> children;
  final Widget? trailing;

  const _Secao({required this.titulo, required this.children, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bord, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.mu, letterSpacing: 0.6)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool destaque;

  const _InfoRow(this.label, this.value, {this.destaque = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mu)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
              color: destaque ? AppColors.grn : AppColors.tx,
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DatePickerTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surf,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.bord, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.mu)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.grn),
              const SizedBox(width: 4),
              Text(value, style: const TextStyle(fontSize: 13, color: AppColors.tx, fontWeight: FontWeight.w500)),
            ]),
          ],
        ),
      ),
    );
  }
}
