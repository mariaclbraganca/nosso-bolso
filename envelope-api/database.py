import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

def get_supabase() -> Client:
    url = os.environ.get("SUPABASE_URL")
    key = os.environ.get("SUPABASE_KEY")
    if not url or not key:
        raise RuntimeError(
            f"Variáveis de ambiente não configuradas. "
            f"SUPABASE_URL={'SET' if url else 'MISSING'}, "
            f"SUPABASE_KEY={'SET' if key else 'MISSING'}"
        )
    return create_client(url, key)
