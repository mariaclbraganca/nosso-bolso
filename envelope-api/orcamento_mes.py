"""
Orçado por mês: o valor planejado de cada envelope em cada mês.

Mês sem linhas em orcamento_mes usa o valor planejado do próprio envelope
(herdado, como era antes). "Montar a partir do mês anterior" copia o orçado
efetivo do mês anterior; depois cada valor pode ser ajustado só naquele mês.
"""
from typing import Optional


def orcado_efetivo(envelopes: list, linhas_mes: list) -> list:
    """Orçado de cada envelope no mês: o gravado no mês ou, sem ele, o do envelope."""
    gravado = {l["envelope_id"]: float(l["valor_planejado"]) for l in linhas_mes}
    return [{
        "envelope_id": e["id"],
        "valor_planejado": gravado[e["id"]] if e["id"] in gravado else float(e.get("valor_planejado") or 0),
        "fonte": "mes" if e["id"] in gravado else "herdado",
    } for e in envelopes]


def montar_a_partir(envelopes: list, linhas_anterior: list, mes: str, familia_id: str) -> list:
    """Linhas do novo mês, copiadas do orçado efetivo do mês anterior."""
    return [{"familia_id": familia_id, "envelope_id": i["envelope_id"], "mes": mes,
             "valor_planejado": i["valor_planejado"]}
            for i in orcado_efetivo(envelopes, linhas_anterior)]
