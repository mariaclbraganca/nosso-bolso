from pymongo import ASCENDING, DESCENDING
from ia_compras.mongo_client import get_sync_db, get_async_db


def get_perfil_metabolico_col():
    return get_sync_db()["perfil_metabolico"]


def get_registro_refeicoes_col():
    return get_sync_db()["registro_refeicoes"]


def get_fotos_progresso_col():
    return get_sync_db()["fotos_progresso"]


def get_registro_peso_col():
    return get_sync_db()["registro_peso"]


def get_relatorio_monitoramento_col():
    return get_sync_db()["relatorio_monitoramento"]


def get_registro_hidratacao_col():
    return get_sync_db()["registro_hidratacao"]


def get_preparo_lote_col():
    return get_sync_db()["preparo_lote"]


# ── Versões async (Motor) ────────────────────────────────────────────────────

def get_async_perfil_metabolico_col():
    return get_async_db()["perfil_metabolico"]


def get_async_registro_refeicoes_col():
    return get_async_db()["registro_refeicoes"]


def ensure_saude_indexes():
    db = get_sync_db()

    db["perfil_metabolico"].create_index(
        [("membro_id", ASCENDING)], unique=True
    )
    db["perfil_metabolico"].create_index(
        [("familia_id", ASCENDING)]
    )

    db["registro_refeicoes"].create_index(
        [("membro_id", ASCENDING), ("data_refeicao", DESCENDING)]
    )
    db["registro_refeicoes"].create_index(
        [("familia_id", ASCENDING), ("data_refeicao", DESCENDING)]
    )
    db["registro_refeicoes"].create_index(
        [("membro_id", ASCENDING), ("deleted_at", ASCENDING)]
    )

    db["fotos_progresso"].create_index(
        [("membro_id", ASCENDING), ("mes_referencia", DESCENDING)]
    )

    db["registro_peso"].create_index(
        [("membro_id", ASCENDING), ("data_medicao", DESCENDING)]
    )

    db["registro_hidratacao"].create_index(
        [("membro_id", ASCENDING), ("data", DESCENDING)], unique=True
    )

    db["preparo_lote"].create_index(
        [("familia_id", ASCENDING), ("validade_estimada", ASCENDING)]
    )

    db["relatorio_monitoramento"].create_index(
        [("membro_id", ASCENDING), ("criado_em", DESCENDING)]
    )
