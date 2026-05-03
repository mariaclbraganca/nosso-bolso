import os
from motor.motor_asyncio import AsyncIOMotorClient
from pymongo import MongoClient, ASCENDING

_MONGO_URL = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
_DB_NAME = os.environ.get("MONGO_DB", "envelope_ia")
_async_client: AsyncIOMotorClient | None = None
_sync_client: MongoClient | None = None

def get_async_db():
    global _async_client
    if _async_client is None:
        _async_client = AsyncIOMotorClient(_MONGO_URL)
    return _async_client[_DB_NAME]

def get_sync_db():
    global _sync_client
    if _sync_client is None:
        _sync_client = MongoClient(_MONGO_URL)
    return _sync_client[_DB_NAME]

def get_compras_collection():
    return get_sync_db()["historico_compras"]

def get_perfis_collection():
    return get_sync_db()["perfil_familia"]

def get_dicionario_collection():
    return get_sync_db()["dicionario_produtos"]

def ensure_indexes():
    db = get_sync_db()
    col = db["historico_compras"]
    col.create_index([("familia_id", ASCENDING)])
    col.create_index([("familia_id", ASCENDING), ("status_integracao", ASCENDING)])
    col.create_index([("familia_id", ASCENDING), ("itens.data_feedback_estimada", ASCENDING)])
    db["dicionario_produtos"].create_index([("familia_id", ASCENDING), ("nome_canonico", ASCENDING)], unique=True)
    db["perfil_familia"].create_index([("familia_id", ASCENDING)], unique=True)
