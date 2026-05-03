"""Seed script — insere perfil_familia padrão no MongoDB (Fase A, item 6).

Uso:
    python -m ia_compras.seed_perfil_familia
    SEED_FAMILIA_ID=<uuid> python -m ia_compras.seed_perfil_familia
"""

import os
from dotenv import load_dotenv

load_dotenv()

from ia_compras.mongo_client import get_perfis_collection, ensure_indexes

FAMILIA_ID = os.environ.get("SEED_FAMILIA_ID", "00000000-0000-0000-0000-000000000001")

PERFIL_PADRAO = {
    "familia_id": FAMILIA_ID,
    "nome_familia": "Família Demo",
    "num_membros": 4,
    "cesta_basica_inegociavel": [
        "Ovos",
        "Peito de Frango",
        "Arroz",
        "Feijão",
        "Macarrão",
        "Tomate",
        "Cenoura",
        "Batata",
        "Leite",
        "Pão de Forma",
        "Queijo Mussarela",
        "Azeite",
        "Sabão em Pó",
    ],
    "restricoes_alimentares": [],
    "regras_financeiras": {
        "limite_mensal": 1200.0,
        "percentual_proteina": 0.30,
        "priorizar_oferta": True,
    },
    "envelope_supermercado_id": None,
}

if __name__ == "__main__":
    ensure_indexes()
    col = get_perfis_collection()
    existente = col.find_one({"familia_id": FAMILIA_ID})
    if existente:
        print(f"[seed] Perfil já existe para familia_id={FAMILIA_ID}")
    else:
        col.insert_one(PERFIL_PADRAO)
        print(f"[seed] Perfil inserido com sucesso para familia_id={FAMILIA_ID}")
