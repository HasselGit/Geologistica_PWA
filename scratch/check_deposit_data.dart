import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== FETCHING DATA LIKE DEPOSITOHOME ===');
  try {
    final pendingViajesRaw = await client
        .from('viajes')
        .select('*, paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores), cargas(id, carga_codigo, estado, carga_items(*))')
        .eq('estado', 'Pendiente')
        .order('fecha', ascending: true);

    final pendingViajes = List<Map<String, dynamic>>.from(pendingViajesRaw);
    for (var v in pendingViajes) {
      if (v['chofer_id'] != null) {
        try {
          final chofer = await client.from('profiles').select('nombre, apellido').eq('id', v['chofer_id']).maybeSingle();
          v['profiles'] = chofer;
        } catch (_) {}
      }
    }

    print('Found ${pendingViajes.length} pending viajes.');
    for (var v in pendingViajes) {
      print('Viaje: ${v['viaje_codigo']} (ID: ${v['id']})');
      final listCargas = v['cargas'] as List? ?? [];
      print('  cargas count: ${listCargas.length}');
      for (var c in listCargas) {
        print('    Carga: ${c['carga_codigo']} (Estado: ${c['estado']})');
        final items = c['carga_items'] as List? ?? [];
        print('      items count: ${items.length}');
        for (var item in items) {
          print('        - ${item['producto_codigo']}: ${item['cantidad']} ${item['unidad']}');
        }
      }
    }
  } catch (e) {
    print('Failed: $e');
  }
}
