import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- TEST CARGAS TERMINADAS ---');
  try {
    final res = await client.from('cargas')
        .select('*, viaje:viaje_id(*, vehiculo:vehiculo_codigo(*)), carga_items(*)')
        .or('estado.eq.Terminado,estado.eq.Terminada')
        .order('updated_at', ascending: false);
    print('✅ Cargas terminadas OK! Encontradas: ${List.from(res).length}');
  } catch (e) {
    print('❌ Error Cargas terminadas: $e');
  }

  print('\n--- TEST PESAJES ---');
  try {
    final data = await client
        .from('pesajes')
        .select('*, parada:parada_id(tipo, localidad, ubicacion, viaje:viaje_id(viaje_codigo, fecha))')
        .order('created_at', ascending: false);
    print('✅ Pesajes OK! Encontrados: ${List.from(data).length}');
  } catch (e) {
    print('❌ Error Pesajes: $e');
  }
}
