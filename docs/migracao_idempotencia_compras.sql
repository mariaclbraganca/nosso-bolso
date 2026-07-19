-- ═══════════════════════════════════════════════════════════════════════════
-- Idempotência de confirmação de compra (evita cobrança dupla)
-- Rodar no SQL Editor do Supabase (uma vez).
-- ═══════════════════════════════════════════════════════════════════════════

-- Coluna que vincula a transação à compra do MongoDB que a originou.
ALTER TABLE transacoes
  ADD COLUMN IF NOT EXISTS origem_ref text;

-- Índice ÚNICO parcial: garante que um mesmo compra_id nunca gere 2 transações
-- ativas (ignora as soft-deleted, permitindo re-registro se uma foi apagada).
-- Se um segundo INSERT com o mesmo origem_ref tentar entrar, o banco rejeita
-- (defesa final, além da checagem no código).
CREATE UNIQUE INDEX IF NOT EXISTS uniq_transacao_origem_ref
  ON transacoes (familia_id, origem_ref)
  WHERE origem_ref IS NOT NULL AND deleted_at IS NULL;

-- Verificação:
-- SELECT indexname FROM pg_indexes WHERE tablename = 'transacoes'
--   AND indexname = 'uniq_transacao_origem_ref';
