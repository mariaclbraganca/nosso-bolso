"""Testes da identidade da compra capturada por notificação (rodar: python test_dedup_notificacao.py)."""
from datetime import datetime

from ia_compras.dedup_notificacao import (
    achar_duplicata, ficar_com_a_mais_antiga, mesma_loja, normalizar, para_iso, registrar_origem,
    registrar_repeticao,
)

FAM = "fam-1"


class ColecaoFalsa:
    """Imita só o que o módulo usa do MongoDB: find com =, $gte, $lte, $in, $exists."""

    def __init__(self):
        self.docs = []

    @staticmethod
    def _bate(valor, cond):
        if not isinstance(cond, dict):
            return valor == cond
        for op, alvo in cond.items():
            if op == "$gte" and not (valor is not None and valor >= alvo): return False
            if op == "$lte" and not (valor is not None and valor <= alvo): return False
            if op == "$in" and valor not in alvo: return False
            if op == "$exists" and (valor is not None) != alvo: return False
        return True

    def find(self, filtro):
        return [d for d in self.docs if all(self._bate(d.get(k), c) for k, c in filtro.items())]

    def insert_one(self, doc): self.docs.append(doc)
    def delete_one(self, f): self.docs = [d for d in self.docs if d["compra_id"] != f["compra_id"]]

    def update_one(self, f, mudanca):
        for d in self.docs:
            if d["compra_id"] == f["compra_id"]:
                d.update(mudanca.get("$set", {}))
                for campo, v in mudanca.get("$addToSet", {}).items():
                    d.setdefault(campo, [])
                    if v not in d[campo]: d[campo].append(v)


def capturar(col, loja, valor, notificado, quem="eu", status="pendente", criado="2026-10-30T14:00:00", fonte="nubank"):
    """Simula o endpoint: devolve 'nova' ou 'duplicata'."""
    iso = para_iso(notificado)
    achada = achar_duplicata(col, FAM, loja, valor, iso, agora=datetime.fromisoformat(criado))
    if achada:
        registrar_repeticao(col, achada, quem, iso, (notificado or "")[:10] or None)
        return "duplicata"
    doc = {"compra_id": f"c{len(col.docs)}", "familia_id": FAM, "supermercado": loja, "valor_total": valor,
           "fonte": fonte, "notificado_em": iso, "origens": [quem], "status_integracao": status, "created_at": criado,
           "data_compra": f"{(iso or criado)[:10]}T00:00:00"}
    if iso is None:
        del doc["notificado_em"]
    col.insert_one(doc)
    return "nova"


def test_mesma_notificacao_relida_horas_depois():
    col = ColecaoFalsa()
    assert capturar(col, "Pet Colosso", 190.0, "2026-10-19T10:30:00", criado="2026-10-19T10:30:05") == "nova"
    # app aberto de novo à noite relê a bandeja: mesma notificação (mesmo horário)
    assert capturar(col, "Pet Colosso", 190.0, "2026-10-19T10:30:00", criado="2026-10-19T21:00:00") == "duplicata"
    assert len(col.docs) == 1


def test_titular_e_cartao_adicional_sao_uma_compra():
    col = ColecaoFalsa()
    assert capturar(col, "Supermercado Leve", 59.31, "2026-10-18T18:00:10", quem="titular") == "nova"
    # o celular do adicional manda 40 segundos depois, mesmo que horas depois no relógio do servidor
    assert capturar(col, "Supermercado Leve", 59.31, "2026-10-18T18:00:50", quem="adicional",
                    criado="2026-10-18T19:40:00") == "duplicata"
    assert col.docs[0]["origens"] == ["titular", "adicional"]


def test_ja_confirmada_ou_cancelada_nao_volta():
    for estado in ("confirmado", "cancelado"):
        col = ColecaoFalsa()
        capturar(col, "Morita", 37.25, "2026-10-19T12:00:00", status=estado)
        assert capturar(col, "Morita", 37.25, "2026-10-19T12:00:00", criado="2026-10-20T08:00:00") == "duplicata"


def test_duas_compras_iguais_de_verdade_ficam_separadas():
    col = ColecaoFalsa()
    assert capturar(col, "Sabor Prime Lanches", 4.0, "2026-10-22T09:00:00") == "nova"
    assert capturar(col, "Sabor Prime Lanches", 4.0, "2026-10-22T15:30:00") == "nova"      # mesmo dia, outra hora
    assert capturar(col, "Sabor Prime Lanches", 4.0, "2026-10-23T09:00:00") == "nova"      # outro dia
    assert len(col.docs) == 3


def test_loja_cortada_pelo_android_e_a_mesma():
    col = ColecaoFalsa()
    capturar(col, "Posto Da Mata", 100.0, "2026-10-16T08:00:00")
    assert capturar(col, "Posto Da Mat", 100.0, "2026-10-16T08:00:20") == "duplicata"
    assert not mesma_loja("Posto Da Mata", "Posto Leste I")
    assert not mesma_loja("Lenda", "Le")           # nome curto demais para tratar como cortado
    assert normalizar("Açaí do Zé!") == "acaidoze"


def test_transicao_captura_antiga_sem_horario_nao_gera_outra():
    """App novo relê a bandeja: a captura antiga (data da leitura, sem horário) é a mesma compra."""
    col = ColecaoFalsa()
    col.insert_one({"compra_id": "velha", "familia_id": FAM, "supermercado": "Pet Colosso", "valor_total": 190.0,
                    "fonte": "nubank", "data_compra": "2026-10-20T00:00:00", "status_integracao": "confirmado",
                    "created_at": "2026-10-20T21:00:00"})       # a notificação era de 19/10, lida no dia 20
    assert capturar(col, "Pet Colosso", 190.0, "2026-10-19T10:30:00", criado="2026-11-04T09:00:00") == "duplicata"
    assert len(col.docs) == 1
    assert col.docs[0]["notificado_em"] == "2026-10-19T10:30:00"        # adotou o horário real
    assert col.docs[0]["data_compra"] == "2026-10-19T00:00:00"          # e a data real da compra
    # a próxima leitura da mesma notificação bate pelo caminho exato
    assert capturar(col, "Pet Colosso", 190.0, "2026-10-19T10:30:00", criado="2026-11-05T09:00:00") == "duplicata"
    # uma compra igual muito depois da antiga continua sendo outra
    assert capturar(col, "Pet Colosso", 190.0, "2026-10-28T10:30:00") == "nova"


def test_valor_diferente_nao_e_duplicata():
    col = ColecaoFalsa()
    capturar(col, "Echope", 6.18, "2026-10-23T10:00:00")
    assert capturar(col, "Echope", 17.64, "2026-10-23T10:00:30") == "nova"


def test_app_antigo_sem_horario_mantem_a_regra_de_10_minutos():
    col = ColecaoFalsa()
    assert capturar(col, "Cb Distribuicao", 11.99, None, criado="2026-10-18T10:00:00") == "nova"
    assert capturar(col, "Cb Distribuicao", 11.99, None, criado="2026-10-18T10:05:00") == "duplicata"
    assert capturar(col, "Cb Distribuicao", 11.99, None, criado="2026-10-18T10:30:00") == "nova"
    # app novo avisando o que um app antigo acabou de mandar
    col2 = ColecaoFalsa()
    capturar(col2, "Pao Nos", 18.0, None, criado="2026-10-30T09:00:00")
    assert capturar(col2, "Pao Nos", 18.0, "2026-10-30T08:59:50", criado="2026-10-30T09:02:00") == "duplicata"


def test_outra_familia_nunca_se_mistura():
    col = ColecaoFalsa()
    capturar(col, "Morita", 66.32, "2026-10-11T12:00:00")
    assert achar_duplicata(col, "fam-2", "Morita", 66.32, para_iso("2026-10-11T12:00:00")) is None


def test_corrida_duas_capturas_simultaneas_sobra_uma():
    col = ColecaoFalsa()
    a = {"compra_id": "a", "familia_id": FAM, "supermercado": "Pet Colosso", "valor_total": 190.0, "fonte": "nubank",
         "notificado_em": "2026-10-19T10:30:00", "created_at": "2026-10-19T10:30:01", "origens": ["x"]}
    b = {**a, "compra_id": "b", "created_at": "2026-10-19T10:30:02", "origens": ["y"]}
    col.insert_one(a); col.insert_one(b)          # as duas passaram juntas pela checagem
    assert ficar_com_a_mais_antiga(col, b, "2026-10-19T10:30:00")["compra_id"] == "a"
    assert ficar_com_a_mais_antiga(col, a, "2026-10-19T10:30:00") is None
    assert [d["compra_id"] for d in col.docs] == ["a"]


def test_horario_com_fuso_vira_horario_de_brasilia():
    assert para_iso("2026-10-19T13:30:00Z") == "2026-10-19T10:30:00"
    assert para_iso("2026-10-19T10:30:00.123") == "2026-10-19T10:30:00"
    assert para_iso("lixo") is None and para_iso(None) is None


if __name__ == "__main__":
    testes = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in testes:
        t()
        print("ok ", t.__name__)
    print(f"{len(testes)} testes passaram")
