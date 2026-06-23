import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Intentando agregar columna "tipo" a "parada_items" ---');
  // Nota: RPC o SQL directo no es fácil sin una función definida.
  // Intentaremos verificar si ya existe.
  try {
    await client.from('parada_items').select('tipo').limit(1);
    print('La columna "tipo" ya existe.');
  } catch (e) {
    print('La columna "tipo" NO existe o hubo un error: $e');
  }
}
