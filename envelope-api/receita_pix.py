"""
Pix recebido vira receita. A mesma notificação pode chegar duas vezes ao mesmo
tempo (listener + leitura da bandeja, ou dois celulares): checar e inserir em
dois passos deixava as duas passarem. Aqui o passo é único: uma trava impede a
corrida dentro do servidor e, depois de inserir, se outra cópia idêntica já
existia (outra instância), fica só a mais antiga.
"""
import threading
from datetime import datetime

_TRAVA = threading.Lock()


def mais_antiga(iguais: list):
    """Entre receitas idênticas, a que deve ficar: criada antes (desempata pelo id)."""
    return min(iguais, key=lambda t: (t.get("created_at") or "", t["id"]), default=None)


def _iguais(db, dados: dict, estabelecimento: str) -> list:
    return (db.table("transacoes").select("id, created_at")
            .eq("familia_id", dados["familia_id"]).eq("tipo", "receita")
            .eq("valor", dados["valor"]).eq("data", dados["data"])
            .is_("deleted_at", "null")
            .ilike("descricao", f"%{estabelecimento}%").execute().data)


def lancar_pix_recebido(db, dados: dict, estabelecimento: str):
    """Lança a receita. Devolve a transação criada, ou None se já existia uma igual."""
    with _TRAVA:
        if _iguais(db, dados, estabelecimento):
            return None
        criada = db.table("transacoes").insert(dados).execute().data[0]
    iguais = _iguais(db, dados, estabelecimento)
    if len(iguais) > 1 and mais_antiga(iguais)["id"] != criada["id"]:
        db.table("transacoes").update({"deleted_at": datetime.now().isoformat()}).eq("id", criada["id"]).execute()
        return None
    return criada
