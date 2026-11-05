"""Testes do Pix recebido sem duplicar (rodar: python test_receita_pix.py)."""
import threading
from receita_pix import lancar_pix_recebido, mais_antiga


class Tabela:
    def __init__(self, db): self.db, self.f, self.op, self.dados = db, {}, "select", None
    def select(self, *_): self.op = "select"; return self
    def insert(self, d): self.op, self.dados = "insert", d; return self
    def update(self, d): self.op, self.dados = "update", d; return self
    def eq(self, k, v): self.f[k] = v; return self
    def is_(self, k, v): self.f[k] = None; return self
    def ilike(self, *_): return self
    def execute(self):
        db = self.db
        if self.op == "insert":
            db.n += 1
            linha = {**self.dados, "id": f"t{db.n}", "created_at": f"2026-11-05T18:40:36.{db.n:06d}", "deleted_at": None}
            db.linhas.append(linha)
            return type("R", (), {"data": [linha]})
        if self.op == "update":
            for l in db.linhas:
                if l["id"] == self.f["id"]: l.update(self.dados)
            return type("R", (), {"data": []})
        achadas = [l for l in db.linhas if l["deleted_at"] is None and all(l.get(k) == v for k, v in self.f.items() if k in ("familia_id", "tipo", "valor", "data"))]
        return type("R", (), {"data": achadas})


class FalsoDb:
    def __init__(self): self.linhas, self.n = [], 0
    def table(self, _): return Tabela(self)


DADOS = {"familia_id": "f", "tipo": "receita", "valor": 5528.15, "data": "2026-11-05", "descricao": "Pix recebido de X"}


def test_segunda_igual_e_ignorada():
    db = FalsoDb()
    assert lancar_pix_recebido(db, dict(DADOS), "X") is not None
    assert lancar_pix_recebido(db, dict(DADOS), "X") is None
    assert len(db.linhas) == 1


def test_duas_ao_mesmo_tempo_sobra_uma():
    db, res = FalsoDb(), []
    ts = [threading.Thread(target=lambda: res.append(lancar_pix_recebido(db, dict(DADOS), "X"))) for _ in range(8)]
    [t.start() for t in ts]; [t.join() for t in ts]
    assert len([l for l in db.linhas if l["deleted_at"] is None]) == 1
    assert len([r for r in res if r]) == 1


def test_mais_antiga():
    assert mais_antiga([{"id": "b", "created_at": "2"}, {"id": "a", "created_at": "1"}])["id"] == "a"


if __name__ == "__main__":
    testes = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for t in testes:
        t(); print("ok ", t.__name__)
    print(f"{len(testes)} testes passaram")
