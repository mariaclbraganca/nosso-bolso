from ia_compras.mongo_client import get_compras_collection
from ia_compras.models_compras import CategoriaItem
from ia_compras.shelf_life import SHELF_LIFE
from datetime import datetime, timedelta


def debitar_itens(
    familia_id: str,
    nome: str,
    quantidade_debitar: float,
) -> bool:
    """
    Debita quantidade do estoque FIFO por nome padronizado.
    Operação best-effort: falha silenciosa se item não encontrado.
    Retorna True se algum débito foi aplicado.
    O caller normaliza o valor para a unidade correta antes de chamar.
    """
    col = get_compras_collection()
    nome_lower = nome.lower()

    docs = list(col.find(
        {
            "familia_id": familia_id,
            "itens": {
                "$elemMatch": {
                    "nome_padronizado": {"$regex": nome_lower, "$options": "i"},
                    "status_consumo": "ativo",
                }
            },
        },
        sort=[("data_compra", 1)],
    ))

    if not docs:
        return False

    restante = quantidade_debitar
    debitou = False

    for doc in docs:
        if restante <= 0:
            break
        for i, item in enumerate(doc.get("itens", [])):
            if restante <= 0:
                break
            if item.get("status_consumo") != "ativo":
                continue
            item_nome = item.get("nome_padronizado", "").lower()
            if nome_lower not in item_nome and item_nome not in nome_lower:
                continue

            qtd = item.get("quantidade", 0)
            if qtd <= 0:
                continue

            if qtd <= restante:
                restante -= qtd
                col.update_one(
                    {"_id": doc["_id"]},
                    {"$set": {
                        f"itens.{i}.status_consumo": "consumido",
                        f"itens.{i}.quantidade": 0,
                    }},
                )
            else:
                col.update_one(
                    {"_id": doc["_id"]},
                    {"$inc": {f"itens.{i}.quantidade": -restante}},
                )
                restante = 0

            debitou = True

    return debitou


def analisar_estoque(familia_id: str) -> dict:
    col = get_compras_collection()
    now = datetime.now()
    docs = list(col.find({
        "familia_id": familia_id,
        "status_integracao": "confirmado",
        "itens.status_consumo": "ativo"
    }))

    estoque: dict[str, dict] = {}
    for doc in docs:
        for item in doc["itens"]:
            if item["status_consumo"] != "ativo":
                continue
            nome = item["nome_padronizado"]
            cat = item.get("categoria", "Outros")
            data_compra = datetime.fromisoformat(doc["data_compra"])
            shelf = SHELF_LIFE.get(CategoriaItem(cat), timedelta(days=30))
            dias_restantes = (data_compra + shelf - now).days

            if nome not in estoque:
                estoque[nome] = {
                    "nome": nome,
                    "categoria": cat,
                    "quantidade": 0,
                    "dias_restantes": dias_restantes,
                    "consumido": False,
                }
            estoque[nome]["quantidade"] += item["quantidade"]
            estoque[nome]["dias_restantes"] = min(
                estoque[nome]["dias_restantes"], dias_restantes
            )
            if dias_restantes <= 0:
                estoque[nome]["consumido"] = True

    return estoque
