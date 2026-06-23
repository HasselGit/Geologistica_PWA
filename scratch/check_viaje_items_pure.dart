import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Viajes in database ---');
    final viajes = await client.from('viajes').select('id, viaje_codigo, estado');
    for (var v in viajes) {
      print('ID: ${v['id']}, Codigo: ${v['viaje_codigo']}, Estado: ${v['estado']}');
      final paradas = await client.from('paradas').select('id, orden_secuencia, tipo, ubicacion, localidad, estado').eq('viaje_id', v['id']);
      for (var p in paradas) {
        print('  Parada ${p['orden_secuencia']}: ${p['tipo']} - ${p['ubicacion']} - State: ${p['estado']} - ID: ${p['id']}');
        
        final items = await client.from('parada_items').select().eq('parada_id', p['id']);
        print('    Items:');
        for (var it in items) {
          print('      - ${it['producto_codigo']}: cantidad=${it['cantidad']}, unidad=${it['unidad']}, id=${it['id']}');
        }
        
        final remitos = await client.from('remitos').select().eq('parada_id', p['id']);
        print('    Remitos:');
        for (var r in remitos) {
          print('      - ID: ${r['id']}, receptor: ${r['persona_nombre']}, fecha: ${r['fecha']}, pdf_url: ${r['pdf_url']}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
