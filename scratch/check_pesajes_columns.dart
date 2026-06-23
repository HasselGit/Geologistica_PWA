import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Columnas de la Tabla: pesajes ---');
  try {
    final sample = await client.from('pesajes').select().limit(1);
    print('Éxito consultando pesajes. Estructura de muestra: $sample');
  } catch (err) {
    print('Error consultando pesajes: $err');
  }
}
