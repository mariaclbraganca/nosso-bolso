import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/jejum_provider.dart';
import '../../../core/providers/usuarios_provider.dart';
import '../../../core/services/jejum_api_service.dart';
import '../../../ui/components/nb_components.dart';
import '../../../ui/theme/nb_theme.dart';
import '../../../ui/unicorn/unicorn.dart';
import '../../sheets/comum.dart';

/// Fast Together: jejuar em dupla. Só marcos positivos do parceiro aparecem.
class JejumTogetherScreen extends ConsumerStatefulWidget {
  const JejumTogetherScreen({super.key, required this.membroId, required this.familiaId});
  final String membroId;
  final String familiaId;

  @override
  ConsumerState<JejumTogetherScreen> createState() => _JejumTogetherScreenState();
}

class _JejumTogetherScreenState extends ConsumerState<JejumTogetherScreen> {
  final _msg = TextEditingController();
  bool _enviando = false;
  Timer? _tique;

  JejumArgs get _args => (membroId: widget.membroId, familiaId: widget.familiaId);

  @override
  void initState() {
    super.initState();
    _tique = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tique?.cancel();
    _msg.dispose();
    super.dispose();
  }

  Future<void> _convidar(String parceiroId) async {
    setState(() => _enviando = true);
    try {
      await JejumApiService.togetherConvite(familiaId: widget.familiaId, usuarioA: widget.membroId, usuarioB: parceiroId);
      ref.invalidate(jejumTogetherDuplaProvider(_args));
      ref.invalidate(jejumTogetherProvider(_args));
      ref.sweet('Agora vocês jejuam juntos. Uma torce pela outra! 💜', mood: UnicornMood.love);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _motivar(String togetherId) async {
    setState(() => _enviando = true);
    try {
      await JejumApiService.togetherMotivar(togetherId: togetherId, remetenteId: widget.membroId, mensagem: _msg.text.trim());
      _msg.clear();
      avisar('Incentivo enviado! 💜');
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jejuar em dupla')),
      body: ref.watch(jejumTogetherDuplaProvider(_args)).when(
            loading: () => const UnicornCarregando(type: UnicornType.happy, texto: 'Chamando sua dupla…'),
            error: (_, __) => _convite(),
            data: (d) => d == null ? _convite() : _dupla(d),
          ),
    );
  }

  Widget _convite() {
    final membros = (ref.watch(listaUsuariosProvider).valueOrNull ?? const [])
        .where((m) => m['id'] != widget.membroId)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
      children: [
        const Center(child: UnicornWidget(type: UnicornType.sweet, size: 120, mood: UnicornMood.love)),
        const SizedBox(height: NBSpacing.l),
        Text('Jejuar com alguém da família', style: NBText.secao, textAlign: TextAlign.center),
        const SizedBox(height: NBSpacing.s),
        Text(
          'Em dupla fica mais fácil manter o hábito. Vocês veem o tempo uma da outra e podem mandar incentivos. '
          'Pausas e interrupções continuam privadas.',
          style: NBText.corpo.copyWith(fontSize: 14, color: NBColors.tintaSuave),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: NBSpacing.xl),
        if (membros.isEmpty)
          Text('Convide alguém para a família em Configurações › Conta e família.',
              style: NBText.legenda, textAlign: TextAlign.center)
        else
          for (final m in membros)
            Padding(
              padding: const EdgeInsets.only(bottom: NBSpacing.s),
              child: CartaoNB(
                onTap: _enviando ? null : () => _convidar(m['id'] as String),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: NBColors.lavandaClara,
                      child: Text(((m['nome'] as String?) ?? '?').characters.first.toUpperCase(),
                          style: NBText.rotulo.copyWith(color: NBColors.lavanda)),
                    ),
                    const SizedBox(width: NBSpacing.m),
                    Expanded(child: Text(m['nome'] as String? ?? '', style: NBText.rotulo)),
                    const Text('Convidar', style: TextStyle(color: NBColors.lavanda, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _dupla(Map<String, dynamic> d) {
    final eu = (d['eu'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parc = (d['parceiro'] as Map?)?.cast<String, dynamic>() ?? const {};
    final mes = (d['mes'] as Map?) ?? const {};
    final togetherId = d['together_id'] as String?;
    final ambos = eu['jejum_ativo'] != null && parc['jejum_ativo'] != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(NBSpacing.margemTela, NBSpacing.s, NBSpacing.margemTela, NBSpacing.x4),
      children: [
        Row(
          children: [
            Expanded(child: CartaoDupla(titulo: 'Você', dados: eu)),
            const SizedBox(width: NBSpacing.s),
            Expanded(child: CartaoDupla(titulo: parc['nome'] as String? ?? 'Dupla', dados: parc)),
          ],
        ),
        if (ambos) ...[
          const SizedBox(height: NBSpacing.m),
          Text('Ambos em jejum agora ✨', style: NBText.rotulo.copyWith(color: NBColors.lavanda), textAlign: TextAlign.center),
        ],
        const SizedBox(height: NBSpacing.l),
        CartaoNB(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Este mês em dupla', style: NBText.rotulo),
              const SizedBox(height: NBSpacing.m),
              Row(
                children: [
                  _Stat('${mes['sincronizados'] ?? 0}', 'dias juntas'),
                  _Stat('${mes['melhor_sequencia_juntas'] ?? 0}', 'melhor sequência'),
                  _Stat('${mes['taxa_combinada'] ?? 0}%', 'em sintonia'),
                ],
              ),
            ],
          ),
        ),
        if (d['mensagem_ia'] is String) ...[
          const SizedBox(height: NBSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const UnicornWidget(type: UnicornType.sweet, size: 56, mood: UnicornMood.love),
              const SizedBox(width: NBSpacing.s),
              Expanded(child: UnicornFala(type: UnicornType.sweet, texto: d['mensagem_ia'] as String, maxWidth: double.infinity)),
            ],
          ),
        ],
        if (togetherId != null) ...[
          const SizedBox(height: NBSpacing.xl),
          Text('Mandar um incentivo', style: NBText.secao),
          const SizedBox(height: 4),
          Text('Chega como notificação. Até 2 por dia, para não virar cobrança.', style: NBText.legenda),
          const SizedBox(height: NBSpacing.m),
          TextField(
            controller: _msg,
            maxLines: 2,
            maxLength: 120,
            decoration: const InputDecoration(hintText: 'Escreva algo ou deixe em branco para a Sweet criar'),
          ),
          FilledButton.icon(
            onPressed: _enviando ? null : () => _motivar(togetherId),
            icon: const Icon(Icons.favorite_rounded, size: 18),
            label: Text(_enviando ? 'Enviando…' : 'Enviar incentivo'),
          ),
        ],
      ],
    );
  }
}

/// Estado de uma das pessoas: tempo de jejum atual (se houver) e sequência.
class CartaoDupla extends StatelessWidget {
  const CartaoDupla({super.key, required this.titulo, required this.dados});
  final String titulo;
  final Map<String, dynamic> dados;

  @override
  Widget build(BuildContext context) {
    final ativo = dados['jejum_ativo'] as Map?;
    final ini = DateTime.tryParse(ativo?['iniciado_em']?.toString() ?? '')?.toLocal();
    final meta = (ativo?['meta_horas'] as num?)?.toDouble() ?? 16;
    final dec = ini == null ? null : DateTime.now().difference(ini);
    return CartaoNB(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: NBText.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: NBSpacing.s),
          if (dec != null) ...[
            Text('${dec.inHours}h${(dec.inMinutes % 60).toString().padLeft(2, '0')}',
                style: NBText.valorCartao.copyWith(color: NBColors.lavanda)),
            const SizedBox(height: 4),
            BarraProgresso(fracao: (dec.inMinutes / (meta * 60)).clamp(0.0, 1.0), cor: NBColors.lavanda),
            const SizedBox(height: 4),
            Text('meta ${meta.round()}h', style: NBText.legenda),
          ] else
            Text('Fora do jejum', style: NBText.corpo.copyWith(color: NBColors.tintaSuave)),
          const SizedBox(height: NBSpacing.s),
          Text('🔥 ${dados['sequencia'] ?? 0} dias', style: NBText.legenda),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.valor, this.rotulo);
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(valor, style: NBText.valorCartao.copyWith(color: NBColors.lavanda)),
            Text(rotulo, style: NBText.legenda, textAlign: TextAlign.center),
          ],
        ),
      );
}
