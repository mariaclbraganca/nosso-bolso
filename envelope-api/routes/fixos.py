from fastapi import APIRouter, Depends, HTTPException
from database import get_supabase
from models import GastoFixoCreate, GastoFixoUpdate
from auth import AuthUser, get_current_user, assert_mesma_familia

router = APIRouter()

@router.get("/")
def listar_fixos(
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None, mes: str = None,
):
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    
    # 1. Buscar fixos do mês solicitado
    query = db.table("gastos_fixos").select("*").eq("familia_id", familia_id).order("dia_vencimento")
    if mes: query = query.eq("mes", mes)
    fixos_atuais = query.execute().data

    # 2. Se for consulta de mês específico, rodar lógica de recorrência (SPEC-04)
    if mes:
        from datetime import datetime, timedelta
        # Calcular mês anterior
        # mes: '2024-04'
        dt = datetime.strptime(mes + "-01", "%Y-%m-%d")
        prev_dt = dt - timedelta(days=1)
        mes_anterior = prev_dt.strftime("%Y-%m")

        # Buscar fixos recorrentes do mês anterior
        fixos_prev = db.table("gastos_fixos").select("*") \
            .eq("familia_id", familia_id) \
            .eq("mes", mes_anterior) \
            .eq("recorrente", True).execute().data
        
        if fixos_prev:
            nomes_atuais = {f["nome"] for f in fixos_atuais}
            novos = []
            for fp in fixos_prev:
                if fp["nome"] not in nomes_atuais:
                    novos.append({
                        "nome": fp["nome"],
                        "valor": fp["valor"],
                        "mes": mes,
                        "familia_id": familia_id,
                        "recorrente": True,
                        "pago": False,
                        "dia_vencimento": fp.get("dia_vencimento")
                    })
            
            if novos:
                # Inserir novos e recarregar
                db.table("gastos_fixos").insert(novos).execute()
                # Recarregar lista para retornar tudo
                fixos_atuais = db.table("gastos_fixos").select("*") \
                    .eq("familia_id", familia_id) \
                    .eq("mes", mes).order("dia_vencimento").execute().data

    return fixos_atuais

@router.post("/")
def criar_fixo(
    payload: GastoFixoCreate,
    user: AuthUser = Depends(get_current_user),
):
    fam = assert_mesma_familia(user, payload.familia_id)
    db = get_supabase()
    data = payload.model_dump()
    data["familia_id"] = fam
    return db.table("gastos_fixos").insert(data).execute().data[0]

@router.patch("/{fixo_id}")
def atualizar_fixo(
    fixo_id: str,
    payload: GastoFixoUpdate,
    user: AuthUser = Depends(get_current_user),
):
    """Atualiza campos do fixo e gerencia saldo_geral se o status 'pago' mudou."""
    db = get_supabase()

    # 1. Busca o fixo atual (filtra por família do usuário)
    fixo_res = db.table("gastos_fixos").select("*") \
        .eq("id", fixo_id).eq("familia_id", user.familia_id).execute().data
    if not fixo_res:
        raise HTTPException(status_code=404, detail="Fixo não encontrado")

    fixo_atual = fixo_res[0]
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}

    if not update_data:
        raise HTTPException(status_code=400, detail="Nenhum campo para atualizar")

    # 2a. Fixo já pago e somente o valor foi alterado: ajustar delta no saldo_geral.
    # Bloco independente do bloco de mudança de status (2b), pois pago não muda aqui.
    fixo_ja_pago = fixo_atual.get("pago", False)
    valor_mudou = (
        "valor" in update_data
        and abs(float(update_data["valor"]) - float(fixo_atual["valor"])) > 0.001
    )
    mudou_status_pago = "pago" in update_data and update_data["pago"] != fixo_ja_pago

    if fixo_ja_pago and valor_mudou and not mudou_status_pago:
        delta = float(update_data["valor"]) - float(fixo_atual["valor"])
        familia_id = fixo_atual["familia_id"]
        saldo_row = db.table("saldo_geral").select("valor_total_disponivel") \
            .eq("familia_id", familia_id).single().execute()
        saldo_atual_val = float(saldo_row.data["valor_total_disponivel"])
        novo_saldo = saldo_atual_val - delta  # delta>0 → cobra mais; delta<0 → estorna
        if novo_saldo < 0:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Saldo insuficiente para corrigir o valor do fixo. "
                    f"Disponível: R$ {saldo_atual_val:.2f} | Delta necessário: R$ {delta:.2f}."
                ),
            )
        db.table("saldo_geral").update({"valor_total_disponivel": novo_saldo}) \
            .eq("familia_id", familia_id).execute()

    # 2b. Se mudou o status de 'pago', ajustar saldo_geral com validação prévia
    if mudou_status_pago:
        valor = float(update_data.get("valor", fixo_atual["valor"]))
        familia_id = fixo_atual["familia_id"]

        # Buscar saldo atual
        saldo_row = db.table("saldo_geral").select("valor_total_disponivel") \
            .eq("familia_id", familia_id).single().execute()
        saldo_atual = float(saldo_row.data["valor_total_disponivel"])

        if update_data["pago"]:
            # Validar antes para retornar 400 limpo em vez de 500 da constraint
            if saldo_atual < valor:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Saldo geral insuficiente para pagar este fixo. "
                        f"Disponível: R$ {saldo_atual:.2f} | Necessário: R$ {valor:.2f}. "
                        f"Remaneje dinheiro de algum envelope para o saldo geral antes."
                    ),
                )
            novo_saldo = saldo_atual - valor
        else:
            novo_saldo = saldo_atual + valor

        db.table("saldo_geral").update({"valor_total_disponivel": novo_saldo}) \
            .eq("familia_id", familia_id).execute()

    # 3. Atualizar registro
    result = db.table("gastos_fixos").update(update_data).eq("id", fixo_id).execute()
    return result.data[0]

@router.delete("/{fixo_id}")
def deletar_fixo(
    fixo_id: str,
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    """Deletar fixo — filtrando sempre pela família do JWT."""
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()
    result = db.table("gastos_fixos").delete().eq("id", fixo_id).eq("familia_id", familia_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Fixo não encontrado")
    return {"ok": True}
