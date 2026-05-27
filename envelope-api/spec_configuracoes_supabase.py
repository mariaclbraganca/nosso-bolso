import psycopg2
import os

DB_URL = os.environ.get("DATABASE_URL", "")
if not DB_URL:
    raise RuntimeError("Defina a variável de ambiente DATABASE_URL antes de executar")

sql = """
-- Tabela global de configurações dinâmicas da aplicação.
-- Substitui a escrita em arquivo .env local (efêmero em containers).
-- O backend lê esta tabela no startup via carregar_config_do_supabase().
CREATE TABLE IF NOT EXISTS public.configuracoes_app (
    chave      text PRIMARY KEY,
    valor      text NOT NULL,
    updated_at timestamptz DEFAULT now()
);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_configuracoes_updated_at ON public.configuracoes_app;
CREATE TRIGGER trg_configuracoes_updated_at
BEFORE UPDATE ON public.configuracoes_app
FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();
"""

try:
    print("Conectando ao banco...")
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()
    print("Executando migração: tabela configuracoes_app...")
    cur.execute(sql)
    conn.commit()
    print("Migration concluída com sucesso!")
    cur.close()
    conn.close()
except Exception as e:
    print(f"Erro na migração: {e}")
