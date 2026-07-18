-- ═══════════════════════════════════════════════════════════════════════════
-- Migração v2 do módulo Jejum — novas colunas para 100% de conformidade
-- Rodar no Supabase SQL Editor. Idempotente (IF NOT EXISTS).
-- ═══════════════════════════════════════════════════════════════════════════

-- ── jejum_config: janela alimentar completa + hidratação + notificações ──────
ALTER TABLE jejum_config
  ADD COLUMN IF NOT EXISTS janela_fim            text,             -- "20:00"
  ADD COLUMN IF NOT EXISTS hidratacao_meta_copos int  DEFAULT 8,
  ADD COLUMN IF NOT EXISTS notif_config          jsonb DEFAULT '{
    "inicio": true, "hidratacao": true, "marco_12h": true, "marco_16h": true,
    "janela_abre": true, "janela_fecha": true, "proteina": false
  }'::jsonb;

-- janela_inicio já existe (v1). Garante default coerente:
ALTER TABLE jejum_config
  ALTER COLUMN janela_inicio SET DEFAULT '12:00';

-- ── jejum_registros: reflexão rica ao encerrar ───────────────────────────────
ALTER TABLE jejum_registros
  ADD COLUMN IF NOT EXISTS sentimento          text,   -- "leve" | "dificuldade" | "cansada_firme" | "energia"
  ADD COLUMN IF NOT EXISTS o_que_ajudou        jsonb,  -- ["hidratacao","cafe","parceiro"]
  ADD COLUMN IF NOT EXISTS motivo_interrupcao  text;   -- "fome" | "social" | "estresse" | "quis"

-- ── usuarios: token FCM (se ainda não existir) ───────────────────────────────
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS fcm_token text;

-- ── Verificação ──────────────────────────────────────────────────────────────
-- SELECT column_name FROM information_schema.columns
--  WHERE table_name = 'jejum_config' ORDER BY ordinal_position;
