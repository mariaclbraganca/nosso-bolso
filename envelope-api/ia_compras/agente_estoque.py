from ia_compras.mongo_client import get_compras_collection
from ia_compras.models_compras import CategoriaItem
from ia_compras.shelf_life import SHELF_LIFE
from datetime import datetime, timedelta


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
