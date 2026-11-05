"""
Apuração do fechamento do mês (regras combinadas com a família).

- Consumo do mês = o que foi lançado nos envelopes (despesas), pela data do gasto.
- Contas fixas = só as que foram pagas/lançadas no mês. Estimativas não contam.
- Fatura do cartão NÃO é saída do mês: ela é o pagamento do consumo no crédito
  que já está nos envelopes. Aparece só como "a pagar no mês seguinte".
- O saldo geral nunca é alterado pelo fechamento.
"""
import calendar

DIA_FECHA_FATURA = 30  # o ciclo da fatura vai do dia 30 do mês anterior ao dia 30


def somar_meses(mes: str, n: int) -> str:
    total = int(mes[:4]) * 12 + int(mes[5:7]) - 1 + n
    return f"{total // 12}-{total % 12 + 1:02d}"


def intervalo_mes(mes: str) -> tuple:
    ultimo = calendar.monthrange(int(mes[:4]), int(mes[5:7]))[1]
    return f"{mes}-01", f"{mes}-{ultimo:02d}"


def ciclo_fatura(mes: str) -> tuple:
    """Compras no crédito que entram na fatura que vence no mês seguinte."""
    ant = somar_meses(mes, -1)
    ultimo_ant = calendar.monthrange(int(ant[:4]), int(ant[5:7]))[1]
    ultimo = calendar.monthrange(int(mes[:4]), int(mes[5:7]))[1]
    return f"{ant}-{min(DIA_FECHA_FATURA, ultimo_ant):02d}", f"{mes}-{min(DIA_FECHA_FATURA, ultimo):02d}"


def _eh_fatura(descricao) -> bool:
    return (descricao or "").strip().lower().startswith("fatura")


def apurar(mes: str, transacoes: list, envelopes: list, compromissos: list,
           fixos_proximo_mes: list, saldo_geral: float, transacoes_ciclo: list) -> dict:
    """Devolve a linha de historico_mensal e as linhas de historico_envelopes."""
    prox = somar_meses(mes, 1)
    receita = consumo = contas = 0.0
    por_env = {}
    for t in transacoes:
        v = float(t["valor"])
        if t["tipo"] == "receita":
            receita += v
        elif t["tipo"] == "despesa":
            consumo += v
            por_env[t.get("envelope_id")] = por_env.get(t.get("envelope_id"), 0.0) + v
        elif t["tipo"] == "despesa_fixa" and not _eh_fatura(t.get("descricao")):
            contas += v
    ini, fim = ciclo_fatura(mes)
    credito = sum(float(t["valor"]) for t in transacoes_ciclo
                  if t["tipo"] == "despesa" and (t.get("forma_pagamento") or "credito") == "credito"
                  and ini <= t["data"][:10] <= fim)
    parcelas_fatura = sum(float(c["valor"]) for c in compromissos if c["mes_fatura"] == prox)
    futuras = [c for c in compromissos if c["mes_fatura"] > prox]
    fatura = round(credito + parcelas_fatura, 2)
    contas_prox = round(sum(float(f["valor"]) - float(f.get("valor_pago") or 0) for f in fixos_proximo_mes if not f.get("pago")), 2)
    a_pagar = round(fatura + contas_prox, 2)
    resultado = round(receita - consumo - contas, 2)
    linhas = [{
        "envelope_id": e["id"], "nome_envelope": e["nome_envelope"], "mes": mes,
        "valor_planejado": float(e.get("valor_planejado") or 0), "total_abastecido": 0.0,
        "total_gasto": round(por_env.get(e["id"], 0.0), 2), "saldo_fechamento": 0.0,
        "natureza": e.get("natureza") or "consumo",
    } for e in envelopes]
    mensal = {
        "mes": mes, "receita_total": round(receita, 2), "total_consumo": round(consumo, 2),
        "total_compromisso": round(contas, 2), "total_objetivo": 0.0, "total_reserva": 0.0,
        "saldo_final": round(float(saldo_geral), 2), "guardado_no_mes": 0.0, "parcelas_do_mes": 0.0,
        "parcelas_restantes_valor": round(sum(float(c["valor"]) for c in futuras), 2),
        "parcelas_restantes_qtd": len(futuras),
        "resultado_mes": resultado, "coberto_por_fora": round(max(0.0, -resultado), 2),
        "extras": {"fatura_cartao": fatura, "contas_mes_seguinte": contas_prox, "a_pagar_mes_seguinte": a_pagar,
                   "saldo_disponivel": round(float(saldo_geral), 2),
                   "falta_cobrir": round(max(0.0, a_pagar - float(saldo_geral)), 2)},
    }
    return {"mensal": mensal, "envelopes": linhas}
