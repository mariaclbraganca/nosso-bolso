-- Tabela para persistir os relatórios do Monitor IA (além do cache local no app).
-- Permite consultar o último relatório fora do dispositivo.

CREATE TABLE IF NOT EXISTS monitor_ia_relatorios (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    familia_id  uuid NOT NULL REFERENCES familias(id) ON DELETE CASCADE,
    status      text,
    titulo      text,
    relatorio   jsonb NOT NULL,       -- MonitorAnalise.toJson() completo
    gerado_em   timestamptz NOT NULL DEFAULT now(),
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_monitor_ia_familia_gerado
    ON monitor_ia_relatorios (familia_id, gerado_em DESC);

-- RLS: cada família só enxerga/insere os próprios relatórios.
ALTER TABLE monitor_ia_relatorios ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS monitor_ia_select ON monitor_ia_relatorios;
CREATE POLICY monitor_ia_select ON monitor_ia_relatorios
    FOR SELECT USING (
        familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid())
    );

DROP POLICY IF EXISTS monitor_ia_insert ON monitor_ia_relatorios;
CREATE POLICY monitor_ia_insert ON monitor_ia_relatorios
    FOR INSERT WITH CHECK (
        familia_id IN (SELECT familia_id FROM usuarios WHERE id = auth.uid())
    );
