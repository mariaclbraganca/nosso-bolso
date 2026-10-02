import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/providers/envelopes_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/utils/moeda.dart';
import '../../ui/components/nb_components.dart';
import '../../ui/theme/nb_theme.dart';
import '../sheets/comum.dart';

/// Sheet para editar uma transação existente no design papel e tinta
class EditTransacaoSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> transacao;

  const EditTransacaoSheet({super.key, required this.transacao});

  @override
  ConsumerState<EditTransacaoSheet> createState() => _EditTransacaoSheetState();
}

class _EditTransacaoSheetState extends ConsumerState<EditTransacaoSheet> {
  late TextEditingController _descricaoCtrl;
  late TextEditingController _valorCtrl;
  String? _envelopeId;
  DateTime _data = DateTime.now();
  bool _salvando = false;

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: '', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _descricaoCtrl = TextEditingController(text: widget.transacao['descricao']?.toString() ?? '');
    final val = (widget.transacao['valor'] as num?)?.toDouble() ?? 0.0;
    _valorCtrl = TextEditingController(text: val > 0 ? _fmt.format(val).trim() : '');
    _envelopeId = widget.transacao['envelope_id']?.toString();
    final dataStr = widget.transacao['data']?.toString();
    if (dataStr != null && dataStr.isNotEmpty) {
      _data = DateTime.tryParse(dataStr) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _descricaoCtrl.dispose();
    _valorCtrl.dispose();
    super.dispose();
  }

  double get _v => parseMoeda(_valorCtrl.text);

  Future<void> _salvar() async {
    final id = widget.transacao['id']?.toString();
    if (id == null) return;
    if (_v <= 0) return avisar('Digite um valor maior que zero.', erro: true);

    final isReceita = (widget.transacao['tipo']?.toString() ?? '') == 'receita';
    final payload = {
      'descricao': _descricaoCtrl.text.trim().isEmpty ? null : _descricaoCtrl.text.trim(),
      'valor': _v,
      'data': DateFormat('yyyy-MM-dd').format(_data),
      if (!isReceita && _envelopeId != null) 'envelope_id': _envelopeId,
    };

    setState(() => _salvando = true);
    try {
      try {
        await ApiService.put('/transacoes/$id', payload);
      } catch (_) {
        await ApiService.patch('/transacoes/$id', payload);
      }
      HapticFeedback.mediumImpact();
      avisar('Transação atualizada com sucesso!');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      avisar(mensagemErro(e), erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final envelopes = ref.watch(envelopesViseisProvider);
    final isReceita = (widget.transacao['tipo']?.toString() ?? '') == 'receita';
    final fmtData = DateFormat("d 'de' MMMM 'de' yyyy", 'pt_BR');

    return CascaSheet(
      filhos: [
        TopoSheet(
          titulo: isReceita ? 'Editar Receita' : 'Editar Despesa',
          subtitulo: 'Ajuste os dados conforme necessário',
        ),
        const SizedBox(height: NBSpacing.l),
        CampoValor(
          controller: _valorCtrl,
          rotulo: 'VALOR',
          corValor: isReceita ? NBColors.verde : NBColors.tinta,
        ),
        const SizedBox(height: NBSpacing.l),
        TextField(
          controller: _descricaoCtrl,
          style: NBText.corpo,
          decoration: const InputDecoration(
            labelText: 'DESCRIÇÃO',
            hintText: 'Ex: Padaria, Farmácia, Combustível...',
          ),
        ),
        const SizedBox(height: NBSpacing.l),
        Text('DATA DA TRANSAÇÃO', style: NBText.eyebrow),
        const SizedBox(height: 6),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _data,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: NBColors.verde,
                    onPrimary: Colors.white,
                    surface: NBColors.cartao,
                    onSurface: NBColors.tinta,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _data = picked);
          },
          borderRadius: BorderRadius.circular(NBRadius.campo),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: NBColors.cartao,
              borderRadius: BorderRadius.circular(NBRadius.campo),
              border: Border.all(color: NBColors.linha),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 18, color: NBColors.tintaSuave),
                const SizedBox(width: 10),
                Expanded(child: Text(fmtData.format(_data), style: NBText.corpo)),
                const Icon(Icons.edit_calendar_rounded, size: 16, color: NBColors.tintaSuave),
              ],
            ),
          ),
        ),
        if (!isReceita) ...[
          const SizedBox(height: NBSpacing.l),
          Text('ENVELOPE', style: NBText.eyebrow),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in envelopes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChipNB(
                      rotulo: e['nome_envelope'] as String? ?? '',
                      selecionado: _envelopeId == e['id'],
                      icone: Text(e['emoji'] as String? ?? '📦', style: const TextStyle(fontSize: 12)),
                      onTap: () => setState(() => _envelopeId = e['id'] as String),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
      botao: BotaoPrincipal(
        rotulo: 'Salvar alterações',
        carregando: _salvando,
        onPressed: _salvar,
      ),
    );
  }
}
