import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import 'usuarios_provider.dart';

// SQL para criar a tabela (rodar no Supabase SQL Editor):
// CREATE TABLE remanejamentos_log (
//   id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
//   familia_id uuid NOT NULL REFERENCES familias(id),
//   usuario_id uuid REFERENCES usuarios(id),
//   envelope_origem_id uuid NOT NULL,
//   envelope_destino_id uuid NOT NULL,
//   valor numeric(10,2) NOT NULL,
//   descricao text,
//   created_at timestamptz NOT NULL DEFAULT now()
// );
// ALTER TABLE remanejamentos_log ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "familia_rw" ON remanejamentos_log
//   USING (familia_id = (SELECT familia_id FROM usuarios WHERE id = auth.uid()));

/// Stream de remanejamentos da família, ordenado por data decrescente.
final remanejamentosProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final perfil = ref.watch(perfilUsuarioLogadoProvider).asData?.value;
  if (perfil == null || perfil['familia_id'] == null) return const Stream.empty();

  final familiaId = perfil['familia_id'] as String;

  return supabase
      .from('remanejamentos_log')
      .stream(primaryKey: ['id'])
      .eq('familia_id', familiaId)
      .order('id', ascending: false)
      .map((rows) => List<Map<String, dynamic>>.from(rows));
});
