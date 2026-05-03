import os
from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter()

_ENV_FILE = os.path.join(os.path.dirname(__file__), "..", ".env")


class ConfiguracaoRequest(BaseModel):
    gemini_api_key: str = ""
    mongo_uri: str = ""


class ConfiguracaoResponse(BaseModel):
    gemini_api_key_configurada: bool
    mongo_uri_configurada: bool


@router.post("/configurar", response_model=ConfiguracaoResponse)
def configurar(payload: ConfiguracaoRequest):
    if payload.gemini_api_key:
        os.environ["GEMINI_API_KEY"] = payload.gemini_api_key
    if payload.mongo_uri:
        os.environ["MONGO_URI"] = payload.mongo_uri
        _reconectar_mongo()
    _salvar_env()
    return ConfiguracaoResponse(
        gemini_api_key_configurada=bool(os.environ.get("GEMINI_API_KEY")),
        mongo_uri_configurada=bool(os.environ.get("MONGO_URI")),
    )


@router.get("/configurar", response_model=ConfiguracaoResponse)
def status_configuracao():
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


def _salvar_env():
    """Persiste as chaves no arquivo .env para sobreviver a restarts."""
    try:
        path = os.path.abspath(_ENV_FILE)
        linhas: dict[str, str] = {}

        if os.path.exists(path):
            with open(path, encoding="utf-8") as f:
                for linha in f:
                    linha = linha.strip()
                    if "=" in linha and not linha.startswith("#"):
                        chave, _, valor = linha.partition("=")
                        linhas[chave.strip()] = valor.strip()

        if os.environ.get("GEMINI_API_KEY"):
            linhas["GEMINI_API_KEY"] = os.environ["GEMINI_API_KEY"]
        if os.environ.get("MONGO_URI"):
            linhas["MONGO_URI"] = os.environ["MONGO_URI"]

        with open(path, "w", encoding="utf-8") as f:
            for chave, valor in linhas.items():
                f.write(f"{chave}={valor}\n")
    except Exception:
        pass
