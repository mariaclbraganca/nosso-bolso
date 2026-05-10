from database import get_supabase
from ia_compras.mongo_client import get_perfis_collection
import logging

logger = logging.getLogger(__name__)


def consultar_saldo_envelope(familia_id: str, envelope_nome: str = "Mercado") -> float:
    """Retorna o saldo do envelope-alvo de compras da família.

    Estratégia:
    1) Lê `envelope_supermercado_id` do perfil_familia (Mongo) — escolha
       explícita do usuário, sobrevive a renomes.
    2) Se não existir, faz fallback por busca textual `ilike "%envelope_nome%"`.
    """
    db = get_supabase()

    try:
        perfil = get_perfis_collection().find_one({"familia_id": familia_id})
    except Exception as e:
        logger.warning(f"perfil_familia indisponivel: {e}")
        perfil = None

    envelope_id = (perfil or {}).get("envelope_supermercado_id")
    if envelope_id:
        result = db.table("envelopes").select("saldo_atual").eq(
            "id", str(envelope_id)
        ).eq("familia_id", familia_id).execute()
        if result.data:
            return result.data[0]["saldo_atual"]
        logger.warning(
            f"envelope_supermercado_id={envelope_id} não encontrado para familia={familia_id}, "
            f"tentando fallback por nome"
        )

    result = db.table("envelopes").select("saldo_atual").eq(
        "familia_id", familia_id
    ).ilike("nome_envelope", f"%{envelope_nome}%").execute()

    if result.data:
        return result.data[0]["saldo_atual"]
    return 0.0


def encontrar_envelopes_com_folga(familia_id: str, valor_necessario: float) -> list[dict]:
    """
    Identifica envelopes com saldo >= valor_necessario que poderiam ser remanejados.
    Exclui envelopes de supermercado/alimentação (V19).
    """
    db = get_supabase()
    result = db.table("envelopes").select("id,nome_envelope,saldo_atual").eq(
        "familia_id", familia_id
    ).gt("saldo_atual", 0).execute()

    envelopes = result.data or []
    _excluir = ("supermercado", "mercado", "alimenta", "compra")
    return [
        {"envelope_id": e["id"], "nome_envelope": e["nome_envelope"], "saldo_atual": e["saldo_atual"]}
        for e in envelopes
        if e["saldo_atual"] >= valor_necessario
        and not any(t in e["nome_envelope"].lower() for t in _excluir)
    ]


def calcular_pressao_orcamentaria(saldo_atual: float, dia_do_mes: int) -> bool:
    """
    Retorna True se o saldo está abaixo de 50% do esperado para o dia.
    Usado para filtrar proteínas premium (V23).
    """
    if dia_do_mes <= 0:
        return False
    dias_restantes = max(1, 30 - dia_do_mes)
    saldo_esperado_proporcional = saldo_atual / dias_restantes * 30
    return saldo_atual < saldo_esperado_proporcional * 0.5
