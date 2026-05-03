from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from database import get_supabase
from models import TransacaoCreate, ReceitaCreate, TransacaoUpdate
from datetime import datetime
import io
import csv

router = APIRouter()

@router.post("/")
def registrar_transacao(payload: TransacaoCreate):
    db = get_supabase()
    data = {
        "valor": payload.valor, "tipo": payload.tipo,
        "usuario_id": str(payload.usuario_id),
        "envelope_id": str(payload.envelope_id) if payload.envelope_id else None,
        "descricao": payload.descricao, "data": str(payload.data),
        "familia_id": str(payload.familia_id),
    }
    result = db.table("transacoes").insert(data).execute()
    return result.data[0]

@router.post("/receita")
def registrar_receita(payload: ReceitaCreate):
    """Atalho semântico: tipo sempre receita, envelope_id sempre null"""
    db = get_supabase()
    data = {
        "valor": payload.valor, "tipo": "receita",
        "usuario_id": str(payload.usuario_id),
        "envelope_id": None,
        "descricao": payload.descricao, "data": str(payload.data),
        "familia_id": str(payload.familia_id),
    }
    result = db.table("transacoes").insert(data).execute()
    return result.data[0]

@router.get("/extrato")
def extrato(familia_id: str, usuario_id: str = None, tipo: str = None,
            envelope_id: str = None, mes: str = None,
            q: str = None, valor_min: float = None, valor_max: float = None,
            data_inicio: str = None, data_fim: str = None,
            page: int = 1, limit: int = 30):
    db = get_supabase()
    query = (db.table("transacoes")
             .select("*, usuarios(nome), envelopes(nome_envelope, emoji)")
             .order("data", desc=True)
             .eq("familia_id", familia_id)
             .is_("deleted_at", "null"))
    
    # Filtros Básicos
    if usuario_id:   query = query.eq("usuario_id", usuario_id)
    if tipo:         query = query.eq("tipo", tipo)
    if envelope_id:  query = query.eq("envelope_id", envelope_id)
    
    # Filtro de Texto (Busca)
    if q:            query = query.ilike("descricao", f"%{q}%")
    
    # Filtros de Valor
    if valor_min:    query = query.gte("valor", valor_min)
    if valor_max:    query = query.lte("valor", valor_max)
    
    # Filtros de Data
    if data_inicio:  query = query.gte("data", data_inicio)
    if data_fim:     query = query.lte("data", data_fim)
    
    # Fallback para Mês (se data_inicio/fim não vierem)
    if mes and not (data_inicio or data_fim):
        import calendar
        year, month = int(mes[:4]), int(mes[5:7])
        last_day = calendar.monthrange(year, month)[1]
        query = query.gte("data", f"{mes}-01").lte("data", f"{mes}-{last_day:02d}")
    
    # Paginação
    query = query.range((page-1)*limit, page*limit-1)
    
    return query.execute().data

@router.get("/export")
def exportar_extrato(familia_id: str, formato: str = "pdf", q: str = None, valor_min: float = None, valor_max: float = None, data_inicio: str = None, data_fim: str = None):
    db = get_supabase()
    query = db.table("transacoes").select("*, envelopes(nome_envelope), usuarios(nome)").eq("familia_id", familia_id).is_("deleted_at", "null").order("created_at", desc=True)
    
    if q: query = query.ilike("descricao", f"%{q}%")
    if valor_min: query = query.gte("valor", valor_min)
    if valor_max: query = query.lte("valor", valor_max)
    if data_inicio: query = query.gte("created_at", data_inicio)
    if data_fim: query = query.lte("created_at", f"{data_fim}T23:59:59")

    dados = query.execute().data

    if formato == "csv":
        output = io.StringIO()
        writer = csv.writer(output)
        writer.writerow(["Data", "Descrição", "Tipo", "Valor", "Envelope", "Usuário"])
        for d in dados:
            writer.writerow([d["created_at"][:10], d["descricao"], d["tipo"], d["valor"], d["envelopes"]["nome_envelope"] if d["envelopes"] else "-", d["usuarios"]["nome"]])
        
        output.seek(0)
        return StreamingResponse(io.BytesIO(output.getvalue().encode()), media_type="text/csv", headers={"Content-Disposition": f"attachment; filename=extrato_{familia_id}.csv"})

    else: # PDF
        from reportlab.lib.pagesizes import A4
        from reportlab.lib import colors
        from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
        from reportlab.lib.styles import getSampleStyleSheet
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        elements = []
        styles = getSampleStyleSheet()
        
        elements.append(Paragraph("Relatório Financeiro — Nosso Bolso", styles['Title']))
        elements.append(Spacer(1, 12))
        
        table_data = [["DATA", "DESCRIÇÃO", "TIPO", "VALOR", "ENVELOPE", "QUEM"]]
        total_dsp = 0
        total_rec = 0
        
        for d in dados:
            v = d["valor"]
            if d["tipo"] == "despesa": total_dsp += v
            else: total_rec += v
            
            table_data.append([
                d["created_at"][:10],
                d["descricao"][:25],
                d["tipo"].upper(),
                f"R$ {v:,.2f}",
                d["envelopes"]["nome_envelope"][:15] if d["envelopes"] else "-",
                d["usuarios"]["nome"]
            ])

        t = Table(table_data)
        t.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor("#0D0D0D")),
            ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
            ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
            ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
            ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
            ('GRID', (0, 0), (-1, -1), 0.5, colors.grey)
        ]))
        elements.append(t)
        elements.append(Spacer(1, 24))
        elements.append(Paragraph(f"<b>Total Despesas:</b> R$ {total_dsp:,.2f}", styles['Normal']))
        elements.append(Paragraph(f"<b>Total Receitas:</b> R$ {total_rec:,.2f}", styles['Normal']))
        elements.append(Paragraph(f"<b>Saldo Período:</b> R$ {(total_rec - total_dsp):,.2f}", styles['Normal']))

        doc.build(elements)
        buffer.seek(0)
        return StreamingResponse(buffer, media_type="application/pdf", headers={"Content-Disposition": f"attachment; filename=extrato_{familia_id}.pdf"})

@router.put("/{transacao_id}")
def editar_transacao(transacao_id: str, familia_id: str, payload: TransacaoUpdate):
    db = get_supabase()
    # Criar dict apenas com campos não-nulos
    update_data = {k: v for k, v in payload.model_dump().items() if v is not None}
    
    if not update_data:
        raise HTTPException(status_code=400, detail="Nenhum campo para atualizar")

    if 'envelope_id' in update_data:
        update_data['envelope_id'] = str(update_data['envelope_id']) if update_data['envelope_id'] else None

    # BOLA Fix: Sempre incluir familia_id em operações de escrita
    result = db.table("transacoes").update(update_data) \
        .eq("id", transacao_id) \
        .eq("familia_id", familia_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Transação não encontrada ou acesso negado")
        
    return result.data[0]

@router.delete("/{transacao_id}")
def excluir_transacao(transacao_id: str, familia_id: str):
    db = get_supabase()
    # Soft delete (SPEC-11)
    result = db.table("transacoes").update({"deleted_at": datetime.now().isoformat()}) \
        .eq("id", transacao_id) \
        .eq("familia_id", familia_id).execute()
    
    if not result.data:
        raise HTTPException(status_code=404, detail="Transação não encontrada ou acesso negado")
    return {"status": "success", "message": "Transação movida para a lixeira"}

@router.get("/lixeira")
def listar_lixeira(familia_id: str):
    db = get_supabase()
    return db.table("transacoes").select("*, envelopes(nome_envelope)") \
        .eq("familia_id", familia_id) \
        .not_.is_("deleted_at", "null") \
        .order("deleted_at", desc=True).execute().data

@router.post("/{transacao_id}/restaurar")
def restaurar_transacao(transacao_id: str, familia_id: str):
    db = get_supabase()
    result = db.table("transacoes").update({"deleted_at": None}) \
        .eq("id", transacao_id) \
        .eq("familia_id", familia_id).execute()
        
    if not result.data:
        raise HTTPException(status_code=404, detail="Não foi possível restaurar")
    return {"status": "success", "message": "Transação restaurada"}
