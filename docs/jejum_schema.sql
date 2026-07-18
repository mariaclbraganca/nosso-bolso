-- ═══════════════════════════════════════════════════════════════════
-- MÓDULO JEJUM INTERMITENTE — Schema Supabase
-- Rodar no SQL Editor do Supabase (uma única vez).
-- Depois: ativar Realtime em jejum_registros (Database → Replication).
-- ═══════════════════════════════════════════════════════════════════

-- ── Tabela 1: jejum_config (1 linha por membro) ─────────────────────
CREATE TABLE IF NOT EXISTS jejum_config (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  familia_id        uuid NOT NULL REFERENCES familias(id) ON DELETE CASCADE,
  usuario_id        uuid NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
  protocolo         text NOT NULL DEFAULT '16_8'
                    CHECK (protocolo IN ('16_8', '18_6', '20_4', '24h', 'personalizado')),
  duracao_horas     numeric(4,1) NOT NULL DEFAULT 16.0,
  modalidade        text NOT NULL DEFAULT 'com_meta'
                    CHECK (modalidade IN ('com_meta', 'livre')),
  janela_inicio     time,
  joker_days_mes    int NOT NULL DEFAULT 2,
  jokers_usados     int NOT NULL DEFAULT 0,
  joker_reset_mes   int,
  sequencia_atual   int NOT NULL DEFAULT 0,
  recorde_sequencia int NOT NULL DEFAULT 0,
  together_ativo    boolean NOT NULL DEFAULT false,
  notif_hidratacao  boolean NOT NULL DEFAULT true,
  notif_fases       boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- ── Tabela 2: jejum_registros (histórico + registro ativo) ──────────
CREATE TABLE IF NOT EXISTS jejum_registros (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  familia_id          uuid NOT NULL REFERENCES familias(id) ON DELETE CASCADE,
  usuario_id          uuid NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  iniciado_em         timestamptz NOT NULL,
  finalizado_em       timestamptz,
  meta_horas          numeric(4,1),
  duracao_real_min    int,
  status              text NOT NULL DEFAULT 'em_andamento'
                      CHECK (status IN ('em_andamento', 'completo', 'interrompido', 'joker')),
  reflexao            text,
  humor_inicio        int CHECK (humor_inicio BETWEEN 1 AND 5),
  humor_fim           int CHECK (humor_fim BETWEEN 1 AND 5),
  is_joker_day        boolean NOT NULL DEFAULT false,
  together_partner_id uuid REFERENCES usuarios(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT now()
);

-- Um único jejum em andamento por usuário
CREATE UNIQUE INDEX IF NOT EXISTS uniq_jejum_ativo
  ON jejum_registros (usuario_id)
  WHERE status = 'em_andamento';

CREATE INDEX IF NOT EXISTS idx_jejum_reg_usuario_data
  ON jejum_registros (usuario_id, iniciado_em DESC);

CREATE INDEX IF NOT EXISTS idx_jejum_reg_familia
  ON jejum_registros (familia_id);

-- ── Tabela 3: jejum_together (vínculo + eventos de motivação) ───────
CREATE TABLE IF NOT EXISTS jejum_together (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  familia_id       uuid NOT NULL REFERENCES familias(id) ON DELETE CASCADE,
  usuario_a        uuid NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  usuario_b        uuid NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  status           text NOT NULL DEFAULT 'ativo'
                   CHECK (status IN ('ativo', 'pausado', 'encerrado')),
  evento           text
                   CHECK (evento IS NULL OR evento IN (
                     'milestone_50pct', 'milestone_completo',
                     'streak_3', 'streak_7',
                     'inicio_jejum', 'lembrete_inicio', 'incentivo_livre')),
  mensagem_ia      text,
  notif_enviada    boolean NOT NULL DEFAULT false,
  notifs_hoje      int NOT NULL DEFAULT 0,
  notifs_reset_dia date,
  created_at       timestamptz NOT NULL DEFAULT now(),
  CHECK (usuario_a <> usuario_b)
);

CREATE INDEX IF NOT EXISTS idx_jejum_together_ativo
  ON jejum_together (familia_id, status);

-- ── Trigger: updated_at automático em jejum_config ──────────────────
CREATE OR REPLACE FUNCTION fn_jejum_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_jejum_config_updated_at ON jejum_config;
CREATE TRIGGER trg_jejum_config_updated_at
  BEFORE UPDATE ON jejum_config
  FOR EACH ROW EXECUTE FUNCTION fn_jejum_config_updated_at();

-- ── Trigger: sequência e recorde ao finalizar jejum ─────────────────
-- completo ou joker  → incrementa sequência (joker também consome 1 joker)
-- interrompido       → zera sequência (privado, sem punição na UI)
CREATE OR REPLACE FUNCTION fn_atualiza_sequencia_jejum()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('completo', 'interrompido', 'joker')
     AND OLD.status = 'em_andamento' THEN

    IF NEW.status = 'completo' OR NEW.status = 'joker' THEN
      UPDATE jejum_config
        SET sequencia_atual   = sequencia_atual + 1,
            recorde_sequencia = GREATEST(recorde_sequencia, sequencia_atual + 1),
            jokers_usados     = CASE WHEN NEW.status = 'joker'
                                     THEN jokers_usados + 1
                                     ELSE jokers_usados END
      WHERE usuario_id = NEW.usuario_id;
    ELSE
      UPDATE jejum_config
        SET sequencia_atual = 0
      WHERE usuario_id = NEW.usuario_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sequencia_jejum ON jejum_registros;
CREATE TRIGGER trg_sequencia_jejum
  AFTER UPDATE ON jejum_registros
  FOR EACH ROW EXECUTE FUNCTION fn_atualiza_sequencia_jejum();

-- ── RLS: padrão família (igual ao restante do app) ──────────────────
ALTER TABLE jejum_config    ENABLE ROW LEVEL SECURITY;
ALTER TABLE jejum_registros ENABLE ROW LEVEL SECURITY;
ALTER TABLE jejum_together  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "familia_jejum_config" ON jejum_config
  FOR ALL TO authenticated
  USING (familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid()))
  WITH CHECK (familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "familia_jejum_registros" ON jejum_registros
  FOR ALL TO authenticated
  USING (familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid()))
  WITH CHECK (familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid()));

CREATE POLICY "familia_jejum_together" ON jejum_together
  FOR ALL TO authenticated
  USING (familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid()))
  WITH CHECK (familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid()));

-- ── Realtime em jejum_registros (timer ao vivo no app) ──────────────
ALTER PUBLICATION supabase_realtime ADD TABLE jejum_registros;
