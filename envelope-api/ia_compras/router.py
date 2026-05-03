from fastapi import APIRouter, HTTPException, BackgroundTasks
from ia_compras.models_compras import (
    IngestaoRequest, CompraExtraida, FeedbackItemRequest,
    ConfirmarCompraRequest, MergeProdutoRequest, ListaComprasGerada, ItemExtraido,
)
from ia_compras.agente_extrator import processar_nota
from ia_compras.mongo_client import get_compras_collection, get_dicionario_collection, get_perfis_collection
from datetime import datetime
from database import get_supabase
import logging

router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/ingestao", status_code=202)
async def ingestao_nota(payload: IngestaoRequest, bg: BackgroundTasks):
    bg.add_task(_processar_background, payload.qr_code_url, str(payload.familia_id))
    return {"compra_id": "pending", "status": "processando"}


def _processar_background(qr_url: str, familia_id: str):
    try:
        import asyncio
        asyncio.run(processar_nota(qr_url, familia_id))
    except Exception as e:
        logger.error(f"Erro ao processar nota: {e}")


@router.get("/pendentes", response_model=list[CompraExtraida])
def listar_pendentes(familia_id: str):
    col = get_compras_collection()
    docs = list(col.find({"familia_id": familia_id, "status_integracao": "pendente"}))
    return [_doc_to_compra(d) for d in docs]


@router.post("/confirmar")
def confirmar_compra(payload: ConfirmarCompraRequest):
    col = get_compras_collection()
    compra = col.find_one({"compra_id": payload.compra_id, "familia_id": str(payload.familia_id)})
    if not compra:
        raise HTTPException(404, "Compra nao encontrada")
    if compra["status_integracao"] != "pendente":
        raise HTTPException(400, f"Compra ja esta com status {compra['status_integracao']}")

    db = get_supabase()
    transacao = {
        "valor": compra["valor_total"],
        "tipo": "despesa",
        "usuario_id": str(payload.usuario_id),
        "envelope_id": str(payload.envelope_id),
        "descricao": f"{compra['supermercado']} — {len(compra['itens'])} itens",
        "data": compra["data_compra"][:10],
        "familia_id": str(payload.familia_id),
    }
    result = db.table("transacoes").insert(transacao).execute()
    if not result.data:
        raise HTTPException(500, "Falha ao registrar transacao no Supabase")

    transacao_id = result.data[0]["id"]
    col.update_one(
        {"compra_id": payload.compra_id},
        {"$set": {"status_integracao": "confirmado", "transacao_supabase_id": transacao_id}}
    )

    envelope = db.table("envelopes").select("saldo_atual").eq("id", str(payload.envelope_id)).execute()
    saldo = envelope.data[0]["saldo_atual"] if envelope.data else 0.0
    return {"transacao_id": transacao_id, "saldo_restante": saldo}


@router.delete("/{compra_id}")
def cancelar_compra(compra_id: str, familia_id: str):
    col = get_compras_collection()
    result = col.update_one(
        {"compra_id": compra_id, "familia_id": familia_id},
        {"$set": {"status_integracao": "cancelado"}}
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Compra nao encontrada")
    return {"status": "cancelado"}


@router.patch("/feedback")
def registrar_feedback(payload: FeedbackItemRequest):
    col = get_compras_collection()
    result = col.update_one(
        {"compra_id": payload.compra_id, "itens.nome_padronizado": payload.nome_padronizado},
        {"$set": {"itens.$.status_consumo": payload.status.value}}
    )
    if result.matched_count == 0:
        raise HTTPException(404, "Item nao encontrado")
    return {"status": payload.status.value}


@router.get("/feedback-pendente")
def feedback_pendente(familia_id: str):
    col = get_compras_collection()
    now = datetime.now().isoformat()
    docs = list(col.find({
        "familia_id": familia_id,
        "status_integracao": "confirmado",
        "itens": {"$elemMatch": {
            "data_feedback_estimada": {"$lte": now},
            "status_consumo": "ativo"
        }}
    }))
    pendentes = []
    for doc in docs:
        for item in doc["itens"]:
            if item["data_feedback_estimada"] <= now and item["status_consumo"] == "ativo":
                pendentes.append({
                    "compra_id": doc["compra_id"],
                    "nome_padronizado": item["nome_padronizado"],
                    "categoria": item["categoria"],
                    "data_compra": doc["data_compra"][:10],
                    "data_feedback_estimada": item["data_feedback_estimada"][:10],
                })
    return pendentes


@router.get("/planejar", response_model=ListaComprasGerada)
def planejar_compras(familia_id: str, dias: int = 15):
    from ia_compras.agente_estoque import analisar_estoque
    from ia_compras.agente_orcamento import consultar_saldo_envelope
    from ia_compras.agente_orquestrador import gerar_lista_inteligente

    estoque = analisar_estoque(familia_id)
    saldo = consultar_saldo_envelope(familia_id)
    perfil = get_perfis_collection().find_one({"familia_id": familia_id}) or {}
    return gerar_lista_inteligente(familia_id, dias, saldo, estoque, perfil)


@router.post("/produtos/merge")
def merge_produtos(payload: MergeProdutoRequest):
    dic = get_dicionario_collection()
    manter = dic.find_one({"_id": _oid(payload.produto_manter_id)})
    remover = dic.find_one({"_id": _oid(payload.produto_remover_id)})
    if not manter or not remover:
        raise HTTPException(404, "Produto nao encontrado")

    sinonimos = list(set(manter.get("sinonimos_llm", []) + remover.get("sinonimos_llm", [])))
    preco = (manter.get("preco_medio", 0) + remover.get("preco_medio", 0)) / 2
    dic.update_one({"_id": manter["_id"]}, {"$set": {"sinonimos_llm": sinonimos, "preco_medio": preco}})
    dic.update_many(
        {"produto_ref_id": str(remover["_id"])},
        {"$set": {"produto_ref_id": str(manter["_id"])}}
    )
    dic.delete_one({"_id": remover["_id"]})
    return {"status": "merged", "produto_id": payload.produto_manter_id}


def _doc_to_compra(doc: dict) -> CompraExtraida:
    itens = []
    for i in doc.get("itens", []):
        itens.append(ItemExtraido(
            nome_original=i["nome_original"],
            nome_padronizado=i["nome_padronizado"],
            categoria=i["categoria"],
            quantidade=i["quantidade"],
            unidade=i["unidade"],
            valor_unitario=i["valor_unitario"],
            valor_total_item=i["valor_total_item"],
        ))
    return CompraExtraida(
        compra_id=doc["compra_id"],
        supermercado=doc["supermercado"],
        valor_total=doc["valor_total"],
        data_compra=datetime.fromisoformat(doc["data_compra"]),
        itens=itens,
        status_integracao=doc.get("status_integracao", "pendente"),
    )


def _oid(s: str):
    from bson.objectid import ObjectId
    try:
        return ObjectId(s)
    except Exception:
        return s
