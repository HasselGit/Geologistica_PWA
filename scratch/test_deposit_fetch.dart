import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== SIMULATING DEPOSITOHOME FETCHDATA (PURE DART) ===');
  try {
    print('1. Querying viajes...');
    final pendingViajesRaw = await client
        .from('viajes')
        .select('*, paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores), cargas(id, carga_codigo, estado, carga_items(*))')
        .eq('estado', 'Pendiente')
        .order('fecha', ascending: true);
    
    print('  Viajes query success, count: ${pendingViajesRaw.length}');

    print('2. Resolving chofer profiles...');
    final List<Map<String, dynamic>> pendingViajes = List<Map<String, dynamic>>.from(pendingViajesRaw);
    for (var v in pendingViajes) {
      if (v['chofer_id'] != null) {
        final chofer = await client
            .from('profiles')
            .select('nombre, apellido')
            .eq('id', v['chofer_id'])
            .maybeSingle();
        v['profiles'] = chofer;
        print('  Resolved chofer for ${v['viaje_codigo']}: ${chofer?['nombre']}');
      }
    }

    print('3. Querying terminated cargas...');
    final history = await client.from('cargas')
        .select('*, viaje:viaje_id(*, profiles(nombre, apellido), vehiculo:vehiculo_codigo(*)), carga_items(*)')
        .eq('estado', 'Terminado')
        .order('updated_at', ascending: false);
    print('  Terminated cargas success, count: ${history.length}');

    print('4. Querying productos...');
    final prods = await client.from('productos').select('*');
    print('  Productos success, count: ${prods.length}');
    
    print('=== ALL OPERATIONS SUCCESSFUL! ===');
  } catch (e, stack) {
    print('Failed with error: $e');
    print('Stack trace:\n$stack');
  }
}
