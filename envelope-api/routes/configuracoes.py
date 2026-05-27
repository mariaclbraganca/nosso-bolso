import os
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from auth import AuthUser, get_current_user
from database import get_supabase

router = APIRouter()


class ConfiguracaoRequest(BaseModel):
    gemini_api_key: str = ""
    mongo_uri: str = ""


class ConfiguracaoResponse(BaseModel):
    gemini_api_key_configurada: bool
    mongo_uri_configurada: bool


@router.post("/configurar", response_model=ConfiguracaoResponse)
def configurar(
    payload: ConfiguracaoRequest,
    user: AuthUser = Depends(get_current_user),
):
    if user.role != "admin":
        raise HTTPException(403, "Apenas admin pode alterar as chaves de IA")

    db = get_supabase()

    if payload.gemini_api_key:
        os.environ["GEMINI_API_KEY"] = payload.gemini_api_key
        db.table("configuracoes_app").upsert(
            {"chave": "GEMINI_API_KEY", "valor": payload.gemini_api_key},
            on_conflict="chave",
        ).execute()

    if payload.mongo_uri:
        os.environ["MONGO_URI"] = payload.mongo_uri
        db.table("configuracoes_app").upsert(
            {"chave": "MONGO_URI", "valor": payload.mongo_uri},
            on_conflict="chave",
        ).execute()
        _reconectar_mongo()

    return ConfiguracaoResponse(
        gemini_api_key_configurada=bool(os.environ.get("GEMINI_API_KEY")),
        mongo_uri_configurada=bool(os.environ.get("MONGO_URI")),
    )


@router.get("/configurar", response_model=ConfiguracaoResponse)
def status_configuracao(user: AuthUser = Depends(get_current_user)):
    return ConfiguracaoResponse(
        gemini_api_key_configurada=bool(os.environ.get("GEMINI_API_KEY")),
        mongo_uri_configurada=bool(os.environ.get("MONGO_URI")),
    )


def _reconectar_mongo():
    try:
        from ia_compras import mongo_client
        mongo_client._sync_client = None
        mongo_client._async_client = None
    except Exception:
        pass


def carregar_config_do_supabase() -> None:
    """Startup: carrega chaves dinâmicas do Supabase para os.environ.

    Variáveis já definidas no ambiente (ex: via Render dashboard) têm
    prioridade — setdefault não sobrescreve valores existentes.
    """
    try:
        db = get_supabase()
        rows = db.table("configuracoes_app").select("chave,valor").execute().data
        for row in rows:
            chave, valor = row.get("chave"), row.get("valor")
            if chave and valor:
                os.environ.setdefault(chave, valor)
    except Exception:
        pass
