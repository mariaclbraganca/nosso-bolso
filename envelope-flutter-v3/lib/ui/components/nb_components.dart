import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/moeda.dart';
import '../theme/nb_theme.dart';

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Aba triangular do envelope (assinatura visual).
class AbaEnvelope extends StatelessWidget {
  const AbaEnvelope({super.key, required this.cor, this.altura = 18});
  final Color cor;
  final double altura;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: altura, width: double.infinity, child: CustomPaint(painter: _AbaPainter(cor)));
}

class _AbaPainter extends CustomPainter {
  _AbaPainter(this.cor);
  final Color cor;

  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width / 2, s.height * 0.95)
      ..lineTo(s.width, 0)
      ..close();
    c.drawPath(p, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_AbaPainter o) => o.cor != cor;
}

/// Estrela de 4 pontas âmbar: marca tudo que vem da IA.
class EstrelaIA extends StatelessWidget {
  const EstrelaIA({super.key, this.tamanho = 20, this.cor = NBColors.ambar});
  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(tamanho), painter: _EstrelaPainter(cor));
}

class _EstrelaPainter extends CustomPainter {
  _EstrelaPainter(this.cor);
  final Color cor;

  @override
  void paint(Canvas c, Size s) {
    final k = s.width / 24;
    final p = Path()
      ..moveTo(12 * k, 3 * k)
      ..cubicTo(12.6 * k, 7.5 * k, 15.5 * k, 10.4 * k, 20 * k, 11 * k)
      ..cubicTo(15.5 * k, 11.6 * k, 12.6 * k, 14.5 * k, 12 * k, 19 * k)
      ..cubicTo(11.4 * k, 14.5 * k, 8.5 * k, 11.6 * k, 4 * k, 11 * k)
      ..cubicTo(8.5 * k, 10.4 * k, 11.4 * k, 7.5 * k, 12 * k, 3 * k)
      ..close();
    c.drawPath(p, Paint()..color = cor);
  }

  @override
  bool shouldRepaint(_EstrelaPainter o) => o.cor != cor;
}

/// Painel escuro de aviso da IA.
class PainelIA extends StatelessWidget {
  const PainelIA({super.key, required this.texto, this.onTap, this.titulo});
  final String texto;
  final String? titulo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NBColors.tinta,
      borderRadius: BorderRadius.circular(NBRadius.cartao),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NBRadius.cartao),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(padding: EdgeInsets.only(top: 1), child: EstrelaIA()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (titulo != null)
                      Text(titulo!, style: NBText.rotulo.copyWith(color: NBColors.ambar)),
                    Text(texto,
                        style: NBText.corpo.copyWith(
                            color: NBColors.papel, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: NBColors.ambar, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Superfície padrão: papel claro, borda fina, sem sombra.
class CartaoNB extends StatelessWidget {
  const CartaoNB({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NBSpacing.l),
    this.onTap,
    this.borda = NBColors.linha,
    this.larguraBorda = 1,
    this.cor = NBColors.cartao,
    this.raio = NBRadius.cartao,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color borda;
  final double larguraBorda;
  final Color cor;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(raio),
      side: BorderSide(color: borda, width: larguraBorda),
    );
    return Material(
      color: cor,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class BarraProgresso extends StatelessWidget {
  const BarraProgresso({super.key, required this.fracao, required this.cor, this.altura = 6, this.trilho = NBColors.afundado});
  final double fracao;
  final Color cor;
  final double altura;
  final Color trilho;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NBRadius.pilula),
      child: SizedBox(
        height: altura,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: trilho)),
            FractionallySizedBox(
              widthFactor: fracao.clamp(0.0, 1.0),
              child: ColoredBox(color: cor, child: SizedBox(height: altura)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado visual de um envelope, derivado dos dados do Supabase e gastos do mês.
class EstadoEnvelope {
  EstadoEnvelope(Map<String, dynamic> env, {this.gastoMes = 0.0})
      : natureza = NaturezaEnvelope.from(env),
        nome = (env['nome_envelope'] as String?) ?? 'Envelope',
        emoji = env['emoji'] as String?,
        saldo = _num(env['saldo_atual']),
        planejado = _num(env['valor_planejado']),
        objetivo = _num(env['valor_objetivo']);

  final NaturezaEnvelope natureza;
  final String nome;
  final String? emoji;
  final double saldo;
  final double planejado;
  final double objetivo;
  final double gastoMes;

  bool get estourado => saldo < 0;

  bool get semPlanejamento => planejado <= 0;

  bool get naoAbastecido => saldo == 0 && gastoMes == 0 && planejado > 0;

  double get fracaoGasta {
    if (planejado <= 0) return 0;
    return (gastoMes / planejado).clamp(0.0, 1.0);
  }

  bool get noLimite => natureza == NaturezaEnvelope.consumo && !estourado && fracaoGasta > 0.85;

  double get fracaoObjetivo => objetivo > 0 ? (saldo / objetivo).clamp(0.0, 1.0) : 0;
}

/// Cartão de envelope com os 5 estados: consumo normal, no limite (>85%),
/// estourado, reserva (acumula) e objetivo (progresso até a meta).
class CartaoEnvelope extends StatelessWidget {
  const CartaoEnvelope({
    super.key,
    required this.env,
    this.gastoMes = 0.0,
    this.onTap,
  });
  final Map<String, dynamic> env;
  final double gastoMes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final e = EstadoEnvelope(env, gastoMes: gastoMes);
    final estourado = e.estourado;

    final Color corValor = estourado
        ? NBColors.estouro
        : switch (e.natureza) {
            NaturezaEnvelope.consumo => NBColors.tinta,
            NaturezaEnvelope.reserva => NBColors.reserva,
            NaturezaEnvelope.objetivo => NBColors.ambarTexto,
          };

    Widget? barra;
    late final Widget legenda;

    if (estourado) {
      barra = const BarraProgresso(fracao: 1, cor: NBColors.estouro, trilho: NBColors.estouro);
      legenda = Text('Estourou · remanejar', style: NBText.legenda.copyWith(color: NBColors.estouro, fontWeight: FontWeight.w700));
    } else {
      switch (e.natureza) {
        case NaturezaEnvelope.consumo:
          if (e.semPlanejamento) {
            legenda = Text('Sem valor planejado', style: NBText.legenda);
          } else if (e.naoAbastecido) {
            legenda = Text('Não abastecido · abastecer ${brl(e.planejado, curto: true)}',
                style: NBText.legenda.copyWith(color: NBColors.tintaSuave));
          } else {

            final pct = (e.fracaoGasta * 100).round();
            barra = BarraProgresso(fracao: e.fracaoGasta, cor: e.noLimite ? NBColors.ambarBarra : NBColors.verde);
            legenda = e.noLimite
                ? Text('$pct% · no limite', style: NBText.legenda.copyWith(color: NBColors.ambarTexto, fontWeight: FontWeight.w700))
                : Text('$pct% de ${brl(e.planejado, curto: true)}', style: NBText.legenda);
          }
        case NaturezaEnvelope.reserva:
          legenda = Text(
            e.planejado > 0 ? 'Acumula · +${brl(e.planejado, curto: true)}' : 'Acumula',
            style: NBText.legenda,
          );
        case NaturezaEnvelope.objetivo:
          if (e.objetivo > 0) {
            barra = BarraProgresso(fracao: e.fracaoObjetivo, cor: NBColors.ambar);
            legenda = Text('${(e.fracaoObjetivo * 100).round()}% de ${brl(e.objetivo, curto: true)}', style: NBText.legenda);
          } else {
            legenda = Text('Objetivo', style: NBText.legenda);
          }
      }
    }

    final semCentavos = e.natureza != NaturezaEnvelope.consumo && !estourado;

    return Semantics(
      button: onTap != null,
      label: '${e.nome}, ${brl(e.saldo)}',
      child: Material(
        color: NBColors.cartao,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NBRadius.cartao),
          side: BorderSide(color: estourado ? NBColors.estouro : NBColors.linha, width: estourado ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: AbaEnvelope(cor: estourado ? NBColors.estouroClaro : e.natureza.aba),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 26, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.nome, style: NBText.rotulo, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(brl(e.saldo, curto: semCentavos), style: NBText.valorCartao.copyWith(color: corValor)),
                    ),
                    if (barra != null) ...[const SizedBox(height: 8), barra],
                    const SizedBox(height: 8),
                    legenda,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Topo de bottom sheet: título grande + apoio opcional.
class TopoSheet extends StatelessWidget {
  const TopoSheet({super.key, required this.titulo, this.subtitulo});
  final String titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: NBText.tituloTela.copyWith(fontSize: 24)),
        if (subtitulo != null) ...[
          const SizedBox(height: 4),
          Text(subtitulo!, style: NBText.corpo.copyWith(color: NBColors.tintaSuave, fontSize: 14)),
        ],
      ],
    );
  }
}

/// Controle segmentado no trilho afundado.
class Segmentado<T> extends StatelessWidget {
  const Segmentado({super.key, required this.opcoes, required this.valor, required this.onChanged});
  final Map<T, String> opcoes;
  final T valor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: NBColors.afundado, borderRadius: BorderRadius.circular(NBRadius.campo)),
      child: Row(
        children: [
          for (final o in opcoes.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(o.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: o.key == valor ? NBColors.cartao : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: o.key == valor ? Border.all(color: NBColors.linha) : null,
                  ),
                  child: Text(
                    o.value,
                    style: NBText.rotulo.copyWith(
                      fontSize: 14,
                      color: o.key == valor ? NBColors.tinta : NBColors.tintaSuave,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip selecionável (pílula).
class ChipNB extends StatelessWidget {
  const ChipNB({super.key, required this.rotulo, required this.selecionado, required this.onTap, this.icone});
  final String rotulo;
  final bool selecionado;
  final VoidCallback onTap;
  final Widget? icone;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selecionado ? NBColors.tinta : NBColors.cartao,
      shape: StadiumBorder(side: BorderSide(color: selecionado ? NBColors.tinta : NBColors.linha, width: 1.5)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icone != null) ...[icone!, const SizedBox(width: 6)],
                Text(rotulo, style: NBText.rotulo.copyWith(fontSize: 14, color: selecionado ? NBColors.papel : NBColors.tinta)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selo pequeno (ex.: "NFC-e", "automático", "lido pela IA").
class SeloNB extends StatelessWidget {
  const SeloNB(this.texto, {super.key, this.cor = NBColors.tintaSuave, this.fundo = NBColors.afundado, this.ia = false});
  final String texto;
  final Color cor;
  final Color fundo;
  final bool ia;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ia) ...[const EstrelaIA(tamanho: 11, cor: NBColors.ambarTexto), const SizedBox(width: 3)],
          Text(texto, style: NBText.legenda.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: cor)),
        ],
      ),
    );
  }
}

/// Campo de valor grande, em reais, com máscara.
class CampoValor extends StatelessWidget {
  const CampoValor({
    super.key,
    required this.controller,
    this.rotulo = 'Valor',
    this.prefixo = 'R\$',
    this.corValor = NBColors.tinta,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String rotulo;
  final String prefixo;
  final Color corValor;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo, style: NBText.rotulo.copyWith(color: NBColors.tintaSuave)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(prefixo, style: NBText.valorCartao.copyWith(color: NBColors.tintaSuave)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: autofocus,
                onChanged: onChanged,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, MoedaInputFormatter()],
                style: NBText.saldo.copyWith(fontSize: 40, color: corValor),
                decoration: InputDecoration(
                  hintText: '0,00',
                  hintStyle: NBText.saldo.copyWith(fontSize: 40, color: NBColors.linha),
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Divider(),
      ],
    );
  }
}

/// Linha "rótulo ......... valor" para prévias de saldo.
class LinhaPrevia extends StatelessWidget {
  const LinhaPrevia({super.key, required this.rotulo, required this.valor, this.corValor = NBColors.tinta});
  final String rotulo;
  final double valor;
  final Color corValor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(rotulo, style: NBText.corpo.copyWith(color: NBColors.tintaSuave, fontSize: 14))),
          Text(brl(valor), style: NBText.corpo.copyWith(fontWeight: FontWeight.w700, color: valor < 0 ? NBColors.estouro : corValor)),
        ],
      ),
    );
  }
}

/// Cabeçalho de seção com ação opcional à direita.
class CabecalhoSecao extends StatelessWidget {
  const CabecalhoSecao({super.key, required this.titulo, this.acao, this.onAcao, this.iconeAcao});
  final String titulo;
  final String? acao;
  final VoidCallback? onAcao;
  final IconData? iconeAcao;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(titulo, style: NBText.secao)),
        if (acao != null)
          TextButton.icon(
            onPressed: onAcao,
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            icon: Icon(iconeAcao ?? Icons.chevron_right_rounded, size: 16),
            label: Text(acao!),
          ),
      ],
    );
  }
}

Future<T?> abrirSheet<T>(BuildContext context, Widget sheet) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: sheet,
    ),
  );
}
