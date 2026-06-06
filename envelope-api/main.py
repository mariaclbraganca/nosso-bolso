from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import envelopes, transacoes, dashboard, abastecer, fixos, remanejar, insights, notificacoes, configuracoes
from routes.configuracoes import carregar_config_do_supabase
from ia_compras.router import router as compras_router
from ia_compras.mongo_client import ensure_indexes
from ia_saude.router_saude import router as saude_router
from ia_saude.router_exercicio import router_exercicio
from ia_saude.mongo_client_saude import ensure_saude_indexes
from ia_financeiro.router_contas import router_contas
from ia_financeiro.router_metas import router_metas
from ia_financeiro.mongo_client_financeiro import ensure_financeiro_indexes

app = FastAPI(title="Envelope App API v2")

@app.on_event("startup")
def startup_event():
    # Carrega chaves dinâmicas (Gemini, Mongo) do Supabase antes de tudo
    carregar_config_do_supabase()
    try:
        ensure_indexes()
    except Exception:
        pass
    try:
        ensure_saude_indexes()
    except Exception:
        pass
    try:
        ensure_financeiro_indexes()
    except Exception:
        pass


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(envelopes.router,  prefix="/envelopes",  tags=["envelopes"])
app.include_router(transacoes.router, prefix="/transacoes", tags=["transacoes"])
app.include_router(dashboard.router,  prefix="/dashboard",  tags=["dashboard"])
app.include_router(abastecer.router,  prefix="/abastecer",  tags=["abastecer"])
app.include_router(fixos.router,      prefix="/fixos",      tags=["fixos"])
app.include_router(remanejar.router,  prefix="/remanejar",  tags=["remanejar"])
app.include_router(insights.router,   prefix="/insights",    tags=["insights"])
app.include_router(notificacoes.router, prefix="/notificacoes", tags=["notificacoes"])
app.include_router(compras_router, prefix="/api/v1/compras", tags=["ia-compras"])
app.include_router(saude_router,     prefix="/api/v1/saude",   tags=["ia-saude"])
app.include_router(router_exercicio,  prefix="/api/v1/saude",       tags=["ia-exercicio"])
app.include_router(router_contas,     prefix="/api/v1/financeiro",   tags=["ia-financeiro"])
app.include_router(router_metas,      prefix="/api/v1/financeiro",   tags=["ia-financeiro"])
app.include_router(configuracoes.router, prefix="/api/v1", tags=["configuracoes"])

@app.get("/")
def health():
    return {"status": "ok", "version": "2.0", "docs": "/docs"}


@app.get("/debug/sefaz")
def debug_sefaz(chave: str = "52260627289076000305652140001007211479511937"):
    """Testa se o Render consegue acessar a SEFAZ-GO."""
    try:
        from ia_compras.scraper_http import criar_sessao, _DEFAULT_TIMEOUT
        sess = criar_sessao()
        base = "https://nfeweb.sefaz.go.gov.br"
        qr_url = f"{base}/nfeweb/sites/nfce/danfeNFCe?p={chave}|3|1"
        r1 = sess.get(qr_url, timeout=_DEFAULT_TIMEOUT)
        url_iframe = f"{base}/nfeweb/sites/nfce/render/danfeNFCe?chNFe={chave}"
        url_html = f"{base}/nfeweb/sites/nfce/render/html/danfeNFCe?chNFe={chave}"
        r2 = sess.get(url_iframe, timeout=_DEFAULT_TIMEOUT)
        r3 = sess.get(url_html, headers={"Referer": url_iframe, "X-Requested-With": "XMLHttpRequest"}, timeout=_DEFAULT_TIMEOUT)
        return {
            "step1_status": r1.status_code,
            "step2_status": r2.status_code,
            "step3_status": r3.status_code,
            "step3_preview": r3.text[:300],
        }
    except Exception as e:
        return {"error": str(e)}


@app.get("/debug/keys")
def debug_keys():
    import os
    chaves = {}
    for sufixo in ("", "_1", "_2", "_3"):
        k = os.environ.get(f"GEMINI_API_KEY{sufixo}", "")
        chaves[f"GEMINI_API_KEY{sufixo}"] = f"{k[:8]}...{k[-4:]}" if len(k) > 12 else ("(vazio)" if not k else k)
    return {"chaves": chaves, "model": os.environ.get("GEMINI_MODEL", "(não set)")}
