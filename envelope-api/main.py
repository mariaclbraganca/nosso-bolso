from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import envelopes, transacoes, dashboard, abastecer, fixos, remanejar, insights, notificacoes, configuracoes
from ia_compras.router import router as compras_router
from ia_compras.mongo_client import ensure_indexes

app = FastAPI(title="Envelope App API v2")

@app.on_event("startup")
def startup_event():
    try:
        ensure_indexes()
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
app.include_router(configuracoes.router, prefix="/api/v1", tags=["configuracoes"])

@app.get("/")
def health():
    return {"status": "ok", "version": "2.0", "docs": "/docs"}
