"""Testes do orçado por mês (rodar: python test_orcamento_mes.py)."""
from orcamento_mes import montar_a_partir, orcado_efetivo

ENVS = [{"id": "a", "valor_planejado": 500}, {"id": "b", "valor_planejado": 100}, {"id": "c", "valor_planejado": 0}]


def test_mes_sem_linhas_herda_do_envelope():
    r = {i["envelope_id"]: (i["valor_planejado"], i["fonte"]) for i in orcado_efetivo(ENVS, [])}
    assert r == {"a": (500, "herdado"), "b": (100, "herdado"), "c": (0, "herdado")}


def test_valor_do_mes_vence_o_do_envelope():
    r = {i["envelope_id"]: i["valor_planejado"] for i in orcado_efetivo(ENVS, [{"envelope_id": "a", "valor_planejado": 450}])}
    assert r["a"] == 450 and r["b"] == 100


def test_montar_copia_o_efetivo_do_mes_anterior():
    novas = montar_a_partir(ENVS, [{"envelope_id": "a", "valor_planejado": 450}], "2026-11", "fam")
    assert {n["envelope_id"]: n["valor_planejado"] for n in novas} == {"a": 450, "b": 100, "c": 0}
    assert all(n["mes"] == "2026-11" and n["familia_id"] == "fam" for n in novas)


if __name__ == "__main__":
    testes = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in testes:
        t(); print("ok ", t.__name__)
    print(f"{len(testes)} testes passaram")
