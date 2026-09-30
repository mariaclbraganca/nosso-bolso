"""
Motor de RECONCILIAÇÃO — confronta a fatura (verdade oficial do crédito) com o
que foi lançado no app (a intenção diária, sujeita a falhas).

Princípio: a máquina SUSPEITA, o humano CONFIRMA. Este módulo não escreve nada
no banco — ele só produz o "laudo" da reconciliação (os quatro baldes). Quem
aplica as decisões é a rota, depois da confirmação do usuário.

Projetado como funções puras para ser testável isoladamente contra CSVs reais.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Optional
import csv
import io
import re


# ── Modelo do que sai do CSV ─────────────────────────────────────────────────

@dataclass
class LinhaFatura:
    """Uma linha da fatura do Nubank (crédito)."""
    data: date
    titulo: str
    valor: float
    # Se for parcela, o título traz "X/Y" — capturamos para casar com a série.
    parcela_num: Optional[int] = None
    parcela_total: Optional[int] = None

    @property
    def eh_parcela(self) -> bool:
        return self.parcela_num is not None

    @property
    def eh_pagamento(self) -> bool:
        """
        'Pagamento recebido' é a quitação da fatura anterior, NÃO uma compra.
        Nunca entra na reconciliação de gastos (senão o app vê um 'gasto'
        negativo gigante). Detectado por título + valor negativo.
        """
        t = self.titulo.lower()
        return self.valor < 0 and ("pagamento" in t and "recebido" in t)

    @property
    def eh_estorno(self) -> bool:
        """Crédito/estorno (ex: 'IOF de volta'): valor negativo que não é pagamento."""
        return self.valor < 0 and not self.eh_pagamento


@dataclass
class LancamentoApp:
    """Uma transação já lançada no app (o que vamos confrontar com a fatura)."""
    id: str
    data: date
    descricao: str
    valor: float
    parcela_id: Optional[str] = None
    parcela_num: Optional[int] = None


# ── Parser do CSV do Nubank ──────────────────────────────────────────────────

_RE_PARCELA = re.compile(r"parcela\s+(\d+)\s*/\s*(\d+)", re.IGNORECASE)


def _parse_valor_br(bruto: str) -> float:
    """
    '4.377,45' → 4377.45 | '4,00' → 4.0 | '- 3,98' → -3.98 | '- 8.435,32' → -8435.32
    Tolera sinal negativo com ou sem espaço (estornos e pagamentos do Nubank).
    """
    s = bruto.strip().strip('"').strip()
    negativo = s.startswith("-")
    if negativo:
        s = s[1:].strip()  # remove o '-' e o espaço que costuma vir depois
    s = s.replace(".", "").replace(",", ".")
    valor = float(s)
    return -valor if negativo else valor


def parse_fatura_csv(conteudo: str) -> list[LinhaFatura]:
    """
    Lê o CSV do Nubank (colunas: date,title,amount) e devolve as linhas.
    Detecta parcelas pelo padrão 'Parcela X/Y' no título.
    """
    linhas: list[LinhaFatura] = []
    reader = csv.DictReader(io.StringIO(conteudo))
    for row in reader:
        # Nomes de coluna tolerantes (date/title/amount, com variações)
        data_raw = (row.get("date") or row.get("data") or "").strip()
        titulo = (row.get("title") or row.get("titulo") or row.get("descricao") or "").strip()
        valor_raw = (row.get("amount") or row.get("valor") or "").strip()
        if not data_raw or not valor_raw:
            continue

        try:
            dt = datetime.strptime(data_raw, "%Y-%m-%d").date()
        except ValueError:
            # tolera DD/MM/YYYY
            try:
                dt = datetime.strptime(data_raw, "%d/%m/%Y").date()
            except ValueError:
                continue

        valor = _parse_valor_br(valor_raw)

        pnum = ptot = None
        m = _RE_PARCELA.search(titulo)
        if m:
            pnum, ptot = int(m.group(1)), int(m.group(2))

        linhas.append(LinhaFatura(data=dt, titulo=titulo, valor=valor,
                                   parcela_num=pnum, parcela_total=ptot))
    return linhas


# ── Resultado da reconciliação (os quatro baldes) ────────────────────────────

@dataclass
class ParCasado:
    """Fatura e app bateram (mesmo valor, data próxima)."""
    fatura: LinhaFatura
    lancamento: LancamentoApp
    divergencia_valor: float = 0.0  # 0 = idêntico; !=0 = casou mas valor difere

    @property
    def valor_diverge(self) -> bool:
        return abs(self.divergencia_valor) >= 0.01


@dataclass
class LaudoReconciliacao:
    """
    O resultado do confronto. Cada balde vira uma seção da tela de confirmação.
    A máquina preenche; o humano decide o que fazer com cada um.
    """
    # Balde 1: casou certinho (confirma sozinho, só resumo)
    casados_ok: list[ParCasado] = field(default_factory=list)
    # Balde 2: na fatura, não lançado → o esquecimento (inserir com data da compra)
    faltando_no_app: list[LinhaFatura] = field(default_factory=list)
    # Balde 3: lançado, não está na fatura → provável débito/PIX (NUNCA apaga)
    so_no_app: list[LancamentoApp] = field(default_factory=list)
    # Balde 4: casou mas valor diverge → humano decide
    divergencia_valor: list[ParCasado] = field(default_factory=list)
    # Fora dos baldes: pagamentos da fatura anterior (quitação, não é gasto)
    pagamentos: list[LinhaFatura] = field(default_factory=list)

    def resumo(self) -> dict:
        return {
            "casaram": len(self.casados_ok),
            "faltando_no_app": len(self.faltando_no_app),
            "so_no_app": len(self.so_no_app),
            "divergencia_valor": len(self.divergencia_valor),
            "pagamentos_ignorados": len(self.pagamentos),
            "total_fatura_gastos": (len(self.casados_ok) + len(self.faltando_no_app)
                                    + len(self.divergencia_valor)),
        }


# ── O motor de de-para ───────────────────────────────────────────────────────

JANELA_DIAS = 3  # tolerância de data: Nubank nunca divergiu mais que isso


def _casa(linha: LinhaFatura, lanc: LancamentoApp, janela: int) -> bool:
    """
    Uma linha da fatura casa com um lançamento do app quando:
    - os valores são iguais (até centavo), E
    - as datas estão dentro da janela de tolerância (default 3 dias).
    Para parcelas, o casamento por X/Y é tratado antes (mais forte que valor+data).
    """
    if abs(linha.valor - lanc.valor) >= 0.01:
        return False
    return abs((linha.data - lanc.data).days) <= janela


def reconciliar(
    fatura: list[LinhaFatura],
    lancamentos: list[LancamentoApp],
    janela_dias: int = JANELA_DIAS,
) -> LaudoReconciliacao:
    """
    Confronta fatura x lançamentos e devolve o laudo (os quatro baldes).

    Estratégia (em duas passadas, do casamento mais forte ao mais fraco):
      1ª passada — PARCELAS: casa pela identidade da parcela (parcela_num +
         valor). É o casamento mais confiável, porque o Nubank já numera "X/Y".
      2ª passada — AVULSAS: casa por valor + data dentro da janela.

    Cada lançamento do app só pode casar uma vez (evita duplo-casamento quando
    há dois valores iguais na mesma semana).
    """
    laudo = LaudoReconciliacao()
    lanc_disponiveis = list(lancamentos)  # cópia mutável; removemos ao casar

    # Pagamentos recebidos (quitação da fatura anterior) NÃO são gastos —
    # separamos e nunca reconciliamos como despesa.
    fatura_gastos = [l for l in fatura if not l.eh_pagamento]
    laudo.pagamentos = [l for l in fatura if l.eh_pagamento]

    fatura_nao_casada: list[LinhaFatura] = []

    # ── 1ª passada: parcelas (casamento forte por número da parcela) ──────────
    for linha in fatura_gastos:
        if not linha.eh_parcela:
            fatura_nao_casada.append(linha)
            continue

        # procura um lançamento de parcela com o mesmo número e valor próximo
        alvo = None
        for lanc in lanc_disponiveis:
            if lanc.parcela_num == linha.parcela_num and abs(lanc.valor - linha.valor) < 0.01:
                alvo = lanc
                break
        if alvo is not None:
            lanc_disponiveis.remove(alvo)
            laudo.casados_ok.append(ParCasado(fatura=linha, lancamento=alvo))
        else:
            # parcela na fatura sem correspondente lançado → faltando
            fatura_nao_casada.append(linha)

    # ── 2ª passada: avulsas (valor + data dentro da janela) ───────────────────
    for linha in fatura_nao_casada:
        candidatos = [l for l in lanc_disponiveis if _casa(linha, l, janela_dias)]
        if candidatos:
            # escolhe o de data mais próxima (desempate estável)
            melhor = min(candidatos, key=lambda l: abs((linha.data - l.data).days))
            lanc_disponiveis.remove(melhor)
            laudo.casados_ok.append(ParCasado(fatura=linha, lancamento=melhor))
            continue

        # Não casou por valor exato. Antes de dar como "faltando", verifica se há
        # um "quase-casamento": mesma data (dentro da janela) e valor PRÓXIMO.
        # Isso pega o erro de digitação de valor (fatura 185, app 180) → balde 4,
        # em vez de criar uma duplicata. Tolerância: 10% ou R$ 5, o que for maior.
        quase = _quase_casa(linha, lanc_disponiveis, janela_dias)
        if quase is not None:
            lanc_disponiveis.remove(quase)
            laudo.divergencia_valor.append(ParCasado(
                fatura=linha, lancamento=quase,
                divergencia_valor=round(linha.valor - quase.valor, 2),
            ))
        else:
            # Nada parecido → é esquecimento genuíno. Humano confirma o insert.
            laudo.faltando_no_app.append(linha)

    # ── Sobrou no app o que a fatura não cobriu → balde 3 (provável débito/PIX)
    laudo.so_no_app = lanc_disponiveis

    return laudo


def _quase_casa(
    linha: LinhaFatura,
    disponiveis: list[LancamentoApp],
    janela: int,
) -> Optional[LancamentoApp]:
    """
    Detecta erro de digitação de VALOR — vira balde 4 (divergência), não duplicata.

    CONSERVADOR DE PROPÓSITO. Testes com fatura real mostraram que "quase-casar"
    por valor+data folgados gera falsos positivos (um PIX de R$50 no dia 15 casa
    à toa com uma compra de R$55 no dia 18, sendo coisas diferentes). Uma fatura
    cheia tem muitas coincidências de valor.

    Então só tratamos como divergência quando a evidência é forte:
      - MESMO DIA (data exata, não janela), E
      - diferença de valor PEQUENA: até R$ 2,00 ou 2% do valor, o que for maior.
    Fora disso, é mais seguro deixar como itens separados (o humano decide).
    """
    melhor = None
    melhor_diff = None
    for l in disponiveis:
        if linha.data != l.data:          # exige mesmo dia
            continue
        if linha.valor <= 0 or l.valor <= 0:
            continue
        tol = max(0.02 * max(linha.valor, l.valor), 2.0)
        diff = abs(linha.valor - l.valor)
        if 0.01 <= diff <= tol:
            if melhor_diff is None or diff < melhor_diff:
                melhor, melhor_diff = l, diff
    return melhor
