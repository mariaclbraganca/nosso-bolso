from pymongo import ASCENDING, DESCENDING
from ia_compras.mongo_client import get_sync_db


def get_contas_pagar_col():
    return get_sync_db()["contas_pagar"]


def get_metas_economia_col():
    return get_sync_db()["metas_economia"]


def ensure_financeiro_indexes():
    db = get_sync_db()

    db["contas_pagar"].create_index(
        [("familia_id", ASCENDING), ("vencimento", ASCENDING)]
    )
    db["contas_pagar"].create_index(
        [("familia_id", ASCENDING), ("pago", ASCENDING)]
    )

    db["metas_economia"].create_index(
        [("familia_id", ASCENDING), ("criado_em", DESCENDING)]
    )
