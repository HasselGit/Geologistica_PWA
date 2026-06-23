import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('Dart Query: Starting...');
  // Initialize Supabase client
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    final voyages = await client.from('viajes').select('*').eq('estado', 'Terminado');
    print('Terminated voyages found: ${voyages.length}');
    for (var v in voyages) {
      print('Viaje: ${v['id']} | Code: ${v['viaje_codigo']} | Estado: ${v['estado']}');
      
      final paradas = await client.from('paradas').select('*, parada_items(*), remitos(*)').eq('viaje_id', v['id']);
      print('  Paradas found: ${paradas.length}');
      for (var p in paradas) {
        print('    Parada: ${p['id']} | Sec: ${p['orden_secuencia']} | Estado: ${p['estado']} | SolId: ${p['solicitud_id']} | RemitoId: ${p['remito_id']}');
        
        final items = p['parada_items'] as List;
        print('      Parada Items in DB (${items.length}):');
        for (var it in items) {
          print('        Item: ${it['producto_codigo']} | Cantidad: ${it['cantidad']} | Unidad: ${it['unidad']}');
        }

        final remitos = p['remitos'] as List;
        print('      Remitos in DB (${remitos.length}):');
        for (var r in remitos) {
          print('        Remito: ${r['id']} | Persona: ${r['persona_nombre']} | PDF: ${r['pdf_url']}');
        }

        // Let's also check for associated solicitudes in DB
        final shortId = p['id'].toString().split('-').first.toUpperCase();
        final sols = await client.from('solicitudes').select('*').or('id.eq.${p['solicitud_id'] ?? "00000000-0000-0000-0000-000000000000"},solicitud_codigo.ilike.SOL-REM-$shortId%');
        print('      Associated Solicitudes in DB (${sols.length}):');
        for (var s in sols) {
          print('        Sol: ${s['solicitud_codigo']} | Product: ${s['producto']} | Cantidad: ${s['cantidad']} | Estado: ${s['estado']}');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
