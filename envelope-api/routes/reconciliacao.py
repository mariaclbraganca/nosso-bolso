"""
Rota de RECONCILIAÇÃO — sobe o CSV da fatura do Nubank (crédito) e o app
confronta com o que foi lançado.

Fluxo (dois passos, respeitando "a máquina suspeita, o humano confirma"):
  1. POST /reconciliacao/analisar  → recebe o CSV, devolve o LAUDO (os 4 baldes).
     NÃO grava nada. É só o diagnóstico para a tela de confirmação.
  2. POST /reconciliacao/aplicar   → recebe as decisões confirmadas pelo usuário
     e efetiva (insere os esquecidos com a data da compra, ajusta divergências).

Só cartão de crédito. Débito/PIX/dinheiro seguem sendo do lançamento manual e
nunca são "cobrados" por não estarem na fatura.
"""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from database import get_supabase
from auth import AuthUser, get_current_user, assert_mesma_familia
from datetime import date, datetime
from reconciliacao.motor import (
    parse_fatura_csv, reconciliar, LancamentoApp,
)

router = APIRouter()


def _laudo_para_json(laudo) -> dict:
    """Serializa o laudo para a tela de confirmação (fila de perguntas sim/não)."""
    def linha(l):
        return {
            "data": l.data.isoformat(),
            "titulo": l.titulo,
            "valor": l.valor,
            "eh_parcela": l.eh_parcela,
            "parcela": f"{l.parcela_num}/{l.parcela_total}" if l.eh_parcela else None,
        }

    def lanc(l):
        return {
            "id": l.id,
            "data": l.data.isoformat(),
            "descricao": l.descricao,
            "valor": l.valor,
        }

    return {
        "resumo": laudo.resumo(),
        # Balde 1: casaram — só para mostrar contagem/lista compacta, sem ação
        "casados_ok": [
            {"fatura": linha(p.fatura), "lancamento": lanc(p.lancamento)}
            for p in laudo.casados_ok
        ],
        # Balde 2: faltando no app — inserir? (com a DATA DA COMPRA)
        "faltando_no_app": [linha(l) for l in laudo.faltando_no_app],
        # Balde 3: só no app — provável débito/PIX, manter? (NUNCA apaga sozinho)
        "so_no_app": [lanc(l) for l in laudo.so_no_app],
        # Balde 4: divergência de valor — qual vale?
        "divergencia_valor": [
            {
                "fatura": linha(p.fatura),
                "lancamento": lanc(p.lancamento),
                "diferenca": p.divergencia_valor,
            }
            for p in laudo.divergencia_valor
        ],
        # Fora dos baldes: pagamentos ignorados (quitação da fatura anterior)
        "pagamentos_ignorados": [linha(l) for l in laudo.pagamentos],
    }


@router.post("/analisar")
async def analisar_fatura(
    familia_id: str,
    arquivo: UploadFile = File(...),
    user: AuthUser = Depends(get_current_user),
):
    """
    Recebe o CSV da fatura, confronta com os lançamentos do período e devolve o
    laudo. NÃO grava nada — é o diagnóstico para o usuário confirmar.
    """
    familia_id = assert_mesma_familia(user, familia_id)
    db = get_supabase()

    # 1. Ler e parsear o CSV
    conteudo_bytes = await arquivo.read()
    try:
        conteudo = conteudo_bytes.decode("utf-8")
    except UnicodeDecodeError:
        conteudo = conteudo_bytes.decode("latin-1")  # tolera acentuação Windows

    fatura = parse_fatura_csv(conteudo)
    if not fatura:
        raise HTTPException(status_code=400, detail="CSV vazio ou em formato não reconhecido.")

    # 2. Descobrir o período coberto pela fatura (menor e maior data de compra)
    datas = [l.data for l in fatura if not l.eh_pagamento]
    if not datas:
        raise HTTPException(status_code=400, detail="A fatura não tem gastos reconciliáveis (só pagamentos).")
    data_min, data_max = min(datas), max(datas)

    # 3. Buscar os lançamentos do app no período (só despesas — crédito).
    #    Trazemos despesas com envelope (compras normais) e parcelas.
    #    NÃO trazemos receita/abastecimento/despesa_fixa (não são compras de cartão).
    resp = (db.table("transacoes")
            .select("id, data, descricao, valor, parcela_id, parcela_num, tipo")
            .eq("familia_id", familia_id)
            .eq("tipo", "despesa")
            .is_("deleted_at", "null")
            .gte("data", data_min.isoformat())
            .lte("data", data_max.isoformat())
            .execute())

    lancamentos = []
    for t in (resp.data or []):
        try:
            d = datetime.strptime(t["data"][:10], "%Y-%m-%d").date()
        except (ValueError, TypeError, KeyError):
            continue
        lancamentos.append(LancamentoApp(
            id=t["id"],
            data=d,
            descricao=t.get("descricao") or "",
            valor=float(t["valor"]),
            parcela_id=t.get("parcela_id"),
            parcela_num=t.get("parcela_num"),
        ))

    # 4. Rodar o motor de reconciliação
    laudo = reconciliar(fatura, lancamentos)

    return {
        "periodo": {"de": data_min.isoformat(), "ate": data_max.isoformat()},
        "arquivo": arquivo.filename,
        **_laudo_para_json(laudo),
    }


@router.post("/aplicar")
def aplicar_reconciliacao(
    payload: dict,
    user: AuthUser = Depends(get_current_user),
):
    """
    Efetiva as decisões que o usuário confirmou na tela.

    payload esperado:
    {
      "familia_id": "...",
      "usuario_id": "...",
      "inserir": [                     # do balde 2 (faltando no app), confirmados
        {"data": "2026-07-15", "titulo": "...", "valor": 123.45, "envelope_id": null}
      ],
      "ajustar_valor": [               # do balde 4 (divergência), confirmados
        {"lancamento_id": "...", "novo_valor": 185.00}
      ]
      // Balde 3 (só no app) não gera ação: manter é o default (não apaga nada).
    }
    """
    familia_id = assert_mesma_familia(user, payload.get("familia_id"))
    usuario_id = payload.get("usuario_id") or user.id
    db = get_supabase()

    inseridos = 0
    ajustados = 0

    # Inserir os esquecidos (com a DATA DA COMPRA que veio da fatura)
    novos = []
    for item in payload.get("inserir", []):
        valor = float(item["valor"])
        if valor <= 0:
            continue  # ignora estornos/negativos na inserção de gastos
        novos.append({
            "familia_id": familia_id,
            "usuario_id": usuario_id,
            "tipo": "despesa",
            "valor": valor,
            "data": item["data"],  # data da compra, não de hoje
            "descricao": item.get("titulo") or "Reconciliado da fatura",
            "envelope_id": item.get("envelope_id"),
        })
    if novos:
        db.table("transacoes").insert(novos).execute()
        inseridos = len(novos)

    # Ajustar valores divergentes (o usuário confirmou que a fatura é a verdade)
    for item in payload.get("ajustar_valor", []):
        lid = item["lancamento_id"]
        novo = float(item["novo_valor"])
        db.table("transacoes").update({"valor": novo}) \
            .eq("id", lid).eq("familia_id", familia_id).execute()
        ajustados += 1

    return {
        "status": "success",
        "inseridos": inseridos,
        "ajustados": ajustados,
        "mensagem": f"{inseridos} lançamento(s) inserido(s), {ajustados} ajuste(s) de valor.",
    }
