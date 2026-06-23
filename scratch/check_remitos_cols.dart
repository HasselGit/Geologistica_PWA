import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Tabla remitos ---');
  final testCols = [
    'id', 'parada_id', 'apicultor_id', 'pdf_url', 'remito_codigo', 'estado',
    'entidad_nombre', 'firmante_nombre', 'firmante_dni', 'firma_base64',
    'tipo', 'fecha', 'items', 'firma_url', 'created_at'
  ];

  for (var col in testCols) {
    try {
      await client.from('remitos').select(col).limit(1);
      print('  [OK] "$col"');
    } catch (e) {
      print('  [FAIL] "$col": $e');
    }
  }
}
