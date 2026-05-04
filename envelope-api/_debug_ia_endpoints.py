"""Teste end-to-end de TODOS os endpoints de IA-Compras.
Roda em isolamento: usa família real do Supabase, mas reverte tudo no final.
Não comita nada de novo no banco produtivo.
"""
import asyncio
import sys
import time
import uuid
import json

sys.stdout.reconfigure(encoding="utf-8")

from dotenv import load_dotenv
load_dotenv()

from fastapi.testclient import TestClient
from main import app
from ia_compras.mongo_client import (
    get_compras_collection,
    get_dicionario_collection,
    get_perfis_collection,
)
from database import get_supabase

FAM = "a1b2c3d4-0000-4000-a000-000000000001"
USR = "8ef33e82-1c59-42f5-9ab6-dcadf0cd66dd"
ENV = "70331e8f-b03b-44af-b6ba-c1f2cbdcdb3d"  # Complemento do Supermercado
QR = (
    "https://nfeweb.sefaz.go.gov.br/nfeweb/sites/nfce/danfeNFCe?p="
    "52260524815086000411651070002983861845966725|2|1|1|"
    "785483DA408C7D68E959236903D99D42067F7E31"
)

client = TestClient(app)
db = get_supabase()


def banner(t):
    print("\n" + "=" * 70 + f"\n  {t}\n" + "=" * 70)


def saldo_envelope():
    r = db.table("envelopes").select("saldo_atual").eq("id", ENV).execute()
    return r.data[0]["saldo_atual"] if r.data else None


def main():
    saldo_inicial = saldo_envelope()
    print(f"Saldo INICIAL do envelope: R$ {saldo_inicial}")

    # --- 1. INGESTÃO ---
    banner("1) POST /api/v1/compras/ingestao")
    r = client.post(
        "/api/v1/compras/ingestao",
        json={"familia_id": FAM, "qr_code_url": QR},
    )
    print("status:", r.status_code, "body:", r.json())
    assert r.status_code == 202

    print("aguardando background processar (45s)...")
    time.sleep(45)

    # --- 2. PENDENTES ---
    banner("2) GET /api/v1/compras/pendentes")
    r = client.get("/api/v1/compras/pendentes", params={"familia_id": FAM})
    pendentes = r.json()
    minha = next((p for p in pendentes if abs(p["valor_total"] - 184.43) < 0.01), None)
    if not minha:
        print("FAIL: compra não apareceu em /pendentes")
        print("pendentes:", pendentes)
        return
    compra_id = minha["compra_id"]
    print(
        f"OK — compra_id={compra_id}, super={minha['supermercado']!r}, "
        f"valor={minha['valor_total']}, itens={len(minha['itens'])}"
    )

    # --- 3. CONFIRMAR ---
    banner("3) POST /api/v1/compras/confirmar (cria transacao no Supabase)")
    r = client.post(
        "/api/v1/compras/confirmar",
        json={
            "compra_id": compra_id,
            "familia_id": FAM,
            "usuario_id": USR,
            "envelope_id": ENV,
        },
    )
    print("status:", r.status_code, "body:", r.json())
    if r.status_code != 200:
        print("FAIL ao confirmar")
        return
    transacao_id = r.json()["transacao_id"]
    saldo_pos = saldo_envelope()
    print(f"saldo após confirmar: R$ {saldo_pos} (delta esperado -184.43)")

    # --- 4. FEEDBACK ---
    banner("4) PATCH /api/v1/compras/feedback")
    nome_item = minha["itens"][0]["nome_padronizado"]
    r = client.patch(
        "/api/v1/compras/feedback",
        json={
            "compra_id": compra_id,
            "nome_padronizado": nome_item,
            "status": "acabou",
        },
    )
    print("status:", r.status_code, "body:", r.json())

    # --- 5. FEEDBACK-PENDENTE ---
    banner("5) GET /api/v1/compras/feedback-pendente")
    # forçar data_feedback_estimada para o passado num item
    nome_outro = minha["itens"][1]["nome_padronizado"]
    get_compras_collection().update_one(
        {"compra_id": compra_id, "itens.nome_padronizado": nome_outro},
        {"$set": {"itens.$.data_feedback_estimada": "2020-01-01T00:00:00"}},
    )
    r = client.get("/api/v1/compras/feedback-pendente", params={"familia_id": FAM})
    pend_fb = r.json()
    encontrou = any(p["nome_padronizado"] == nome_outro for p in pend_fb)
    print(f"status: {r.status_code}, total pendentes: {len(pend_fb)}, "
          f"contém o item forçado: {encontrou}")

    # --- 6. PLANEJAR ---
    banner("6) GET /api/v1/compras/planejar?dias=15")
    r = client.get(
        "/api/v1/compras/planejar", params={"familia_id": FAM, "dias": 15}
    )
    print("status:", r.status_code)
    if r.status_code == 200:
        body = r.json()
        print(
            f"saldo={body['saldo_envelope']}, custo_estimado={body['custo_estimado_total']}, "
            f"itens={len(body['itens'])}, dentro_orc={body['dentro_do_orcamento']}"
        )
        if body["itens"]:
            print("primeiro item:", body["itens"][0])
    else:
        print("body:", r.text[:500])

    # --- 7. PRODUTOS/MERGE ---
    banner("7) POST /api/v1/compras/produtos/merge")
    dic = get_dicionario_collection()
    a = dic.insert_one({
        "familia_id": "_test_merge_",
        "nome_canonico": "Produto A teste",
        "categoria": "Outros",
        "sinonimos_llm": ["A1"],
        "preco_medio": 10.0,
    }).inserted_id
    b = dic.insert_one({
        "familia_id": "_test_merge_",
        "nome_canonico": "Produto B teste",
        "categoria": "Outros",
        "sinonimos_llm": ["B1"],
        "preco_medio": 20.0,
    }).inserted_id
    r = client.post(
        "/api/v1/compras/produtos/merge",
        json={"produto_manter_id": str(a), "produto_remover_id": str(b)},
    )
    print("status:", r.status_code, "body:", r.json())
    after = dic.find_one({"_id": a})
    print(f"sinonimos: {after.get('sinonimos_llm')}, preco: {after.get('preco_medio')}")
    dic.delete_one({"_id": a})

    # --- 8. CANCELAR (cleanup compra) ---
    banner("8) DELETE /api/v1/compras/{compra_id}")
    # Para cancelar, primeiro reverto o status para pendente (já que confirmar deixou confirmado)
    get_compras_collection().update_one(
        {"compra_id": compra_id},
        {"$set": {"status_integracao": "pendente"}},
    )
    r = client.delete(
        f"/api/v1/compras/{compra_id}", params={"familia_id": FAM}
    )
    print("status:", r.status_code, "body:", r.json())

    # --- 9. REVERTER TRANSACAO NO SUPABASE ---
    banner("9) Revertendo transação no Supabase (cleanup)")
    db.table("transacoes").delete().eq("id", transacao_id).execute()
    saldo_final = saldo_envelope()
    print(f"saldo FINAL: R$ {saldo_final} (deveria == inicial R$ {saldo_inicial})")

    # remove o doc Mongo de teste
    get_compras_collection().delete_many({"compra_id": compra_id})

    banner("FIM — todos os endpoints testados")


if __name__ == "__main__":
    main()
