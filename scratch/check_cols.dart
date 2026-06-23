import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Columnas de carga_items via RPC/Select ---');
  try {
    // Intentemos obtener de pg_attribute o similar si hay alguna rpc genérica
    // Si no, hagamos un insert y forcemos un error de tipo para ver qué campos espera
    final res = await client.from('carga_items').insert({
      'carga_id': 'invalid-uuid',
    }).select();
    print('Res: $res');
  } catch (e) {
    print('Error capturado para ver columnas: $e');
  }
}
