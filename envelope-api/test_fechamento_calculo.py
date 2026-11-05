"""Testes do fechamento do mês (rodar: python test_fechamento_calculo.py)."""
from fechamento_calculo import apurar, ciclo_fatura, somar_meses

ENV = [{"id": "e1", "nome_envelope": "Lazer", "valor_planejado": 200, "natureza": "consumo"},
       {"id": "e2", "nome_envelope": "Combustível", "valor_planejado": 500, "natureza": "consumo"}]


def tx(tipo, valor, data, forma=None, env=None, desc=""):
    return {"tipo": tipo, "valor": valor, "data": data, "forma_pagamento": forma, "envelope_id": env, "descricao": desc}


def montar():
    mes = [tx("receita", 3000, "2026-10-05"), tx("despesa", 100, "2026-10-10", "credito", "e1"),
           tx("despesa", 50, "2026-10-11", "pix", "e2"), tx("despesa_fixa", 2000, "2026-10-07", desc="Aluguel (fixo 2026-10)"),
           tx("despesa_fixa", 7000, "2026-10-07", desc="Fatura Aruã (fixo 2026-10)")]
    ciclo = mes + [tx("despesa", 20, "2026-09-30", "credito", "e1"), tx("despesa", 99, "2026-09-29", "credito", "e1"),
                   tx("despesa", 70, "2026-10-31", "credito", "e1")]
    comps = [{"valor": 300, "mes_fatura": "2026-11"}, {"valor": 300, "mes_fatura": "2026-12"}, {"valor": 300, "mes_fatura": "2027-01"}]
    fixos = [{"valor": 600, "valor_pago": 0, "pago": False}, {"valor": 100, "valor_pago": 100, "pago": True}]
    return apurar("2026-10", mes, ENV, comps, fixos, 6000, ciclo)


def test_consumo_e_contas_nao_incluem_fatura():
    m = montar()["mensal"]
    assert m["total_consumo"] == 150 and m["total_compromisso"] == 2000     # fatura de 7000 fora
    assert m["resultado_mes"] == 3000 - 150 - 2000 and m["coberto_por_fora"] == 0


def test_a_pagar_no_mes_seguinte():
    ex = montar()["mensal"]["extras"]
    assert ex["fatura_cartao"] == 100 + 20 + 300          # crédito de 30/09 a 30/10 + parcelas da fatura
    assert ex["contas_mes_seguinte"] == 600               # só o que falta pagar
    assert ex["a_pagar_mes_seguinte"] == 1020 and ex["falta_cobrir"] == 0


def test_saldo_nunca_muda_e_sobra_a_cobrir():
    r = apurar("2026-10", [], ENV, [], [{"valor": 500, "valor_pago": 0, "pago": False}], 200, [])
    assert r["mensal"]["saldo_final"] == 200 and r["mensal"]["extras"]["falta_cobrir"] == 300


def test_envelopes_e_parcelas_futuras():
    r = montar()
    assert {l["nome_envelope"]: l["total_gasto"] for l in r["envelopes"]} == {"Lazer": 100, "Combustível": 50}
    assert r["mensal"]["parcelas_restantes_qtd"] == 2 and r["mensal"]["parcelas_restantes_valor"] == 600


def test_ciclo_e_meses():
    assert ciclo_fatura("2026-10") == ("2026-09-30", "2026-10-30")
    assert ciclo_fatura("2026-03") == ("2026-02-28", "2026-03-30")
    assert somar_meses("2026-12", 1) == "2027-01"


if __name__ == "__main__":
    testes = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in testes:
        t(); print("ok ", t.__name__)
    print(f"{len(testes)} testes passaram")
