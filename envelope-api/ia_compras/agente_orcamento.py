from database import get_supabase


def consultar_saldo_envelope(familia_id: str, envelope_nome: str = "Mercado") -> float:
    db = get_supabase()
    result = db.table("envelopes").select("saldo_atual").eq(
        "familia_id", familia_id
    ).ilike("nome_envelope", f"%{envelope_nome}%").execute()

    if result.data:
        return result.data[0]["saldo_atual"]
    return 0.0
