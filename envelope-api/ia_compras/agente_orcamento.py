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
