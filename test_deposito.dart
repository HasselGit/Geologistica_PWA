import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- TEST DEPOSITOHOME FETCH DATA ---');
  try {
    final pendingViajesRaw = await client
        .from('viajes')
        .select('*, paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores), cargas(id, carga_codigo, estado, deposito_origen, carga_items(*))')
        .or('estado.eq.Pendiente,estado.eq.En Proceso,estado.eq.En Curso')
        .order('fecha', ascending: true);
    print('✅ Pending Viajes OK: ${List.from(pendingViajesRaw).length}');
  } catch (e) {
    print('❌ Error Pending Viajes: $e');
  }

  try {
    final res = await client.from('cargas')
        .select('*, viaje:viaje_id(*, vehiculo:vehiculo_codigo(*)), carga_items(*)')
        .or('estado.eq.Terminado,estado.eq.Terminada')
        .order('updated_at', ascending: false);
    print('✅ Cargas Terminadas OK: ${List.from(res).length}');
  } catch (e) {
    print('❌ Error Cargas Terminadas: $e');
  }

  try {
    final prods = await client.from('productos').select('*').order('nombre');
    print('✅ Productos OK: ${List.from(prods).length}');
  } catch (e) {
    print('❌ Error Productos: $e');
  }
}
