import os
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from auth import AuthUser, get_current_user
from database import get_supabase

router = APIRouter()


class ConfiguracaoRequest(BaseModel):
    gemini_api_key: str = ""
    mongo_uri: str = ""
    familia_id: str = ""


class ConfiguracaoResponse(BaseModel):
    gemini_api_key_configurada: bool
    mongo_uri_configurada: bool


def _get_chave_familia(familia_id: str, chave: str) -> str:
    """Lê chave: Supabase global > env numeradas (_1/_2/_3) > env simples."""
    try:
        db = get_supabase()
        row = db.table("configuracoes_app") \
            .select("valor") \
            .eq("chave", chave) \
            .maybe_single() \
            .execute()
        if row.data and row.data.get("valor"):
            return row.data["valor"]
    except Exception:
        pass
    # Variáveis de ambiente: tenta KEY_1, KEY_2, KEY_3 e KEY sem sufixo
    for sufixo in ("_1", "_2", "_3", ""):
        v = os.environ.get(f"{chave}{sufixo}", "").strip()
        if v:
            return v
    return ""


def get_gemini_key(familia_id: str) -> str:
    return _get_chave_familia(familia_id, "GEMINI_API_KEY")


def get_mongo_uri(familia_id: str) -> str:
    return _get_chave_familia(familia_id, "MONGO_URI")


@router.post("/configurar", response_model=ConfiguracaoResponse)
def configurar(
    payload: ConfiguracaoRequest,
    user: AuthUser = Depends(get_current_user),
):
    familia_id = user.familia_id or payload.familia_id
    db = get_supabase()

    if payload.gemini_api_key:
        _upsert_chave(db, "GEMINI_API_KEY", payload.gemini_api_key, familia_id)

    if payload.mongo_uri:
        _upsert_chave(db, "MONGO_URI", payload.mongo_uri, familia_id)
        _reconectar_mongo()

    return ConfiguracaoResponse(
        gemini_api_key_configurada=bool(get_gemini_key(familia_id)),
        mongo_uri_configurada=bool(get_mongo_uri(familia_id)),
    )


@router.get("/configurar", response_model=ConfiguracaoResponse)
def status_configuracao(
    user: AuthUser = Depends(get_current_user),
    familia_id: str = None,
):
    fid = familia_id or user.familia_id or ""
    return ConfiguracaoResponse(
        gemini_api_key_configurada=bool(get_gemini_key(fid)),
        mongo_uri_configurada=bool(get_mongo_uri(fid)),
    )


def _upsert_chave(db, chave: str, valor: str, familia_id: str):
    """Grava chave por família quando a coluna existir; cai para global caso contrário."""
    try:
        db.table("configuracoes_app").upsert(
            {"chave": chave, "valor": valor, "familia_id": familia_id},
            on_conflict="chave,familia_id",
        ).execute()
    except Exception:
        # Coluna familia_id ainda não existe — usa índice global
        db.table("configuracoes_app").upsert(
            {"chave": chave, "valor": valor},
            on_conflict="chave",
        ).execute()


def _reconectar_mongo():
    try:
        from ia_compras import mongo_client
        mongo_client._sync_client = None
        mongo_client._async_client = None
    except Exception:
        pass


def carregar_config_do_supabase() -> None:
    """Startup: carrega chaves globais (sem familia_id) para os.environ como fallback."""
    try:
        db = get_supabase()
        rows = db.table("configuracoes_app") \
            .select("chave,valor") \
            .is_("familia_id", "null") \
            .execute().data
        for row in rows:
            chave, valor = row.get("chave"), row.get("valor")
            if chave and valor:
                os.environ.setdefault(chave, valor)
    except Exception:
        pass
