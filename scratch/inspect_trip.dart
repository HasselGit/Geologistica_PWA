import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== DIAGNOSING TRIP V-2805-119 ===');
  try {
    // 1. Fetch trip details
    final viajes = await client
        .from('viajes')
        .select('*')
        .eq('viaje_codigo', 'V-2805-119');

    if (viajes.isEmpty) {
      print('❌ Trip V-2805-119 not found in "viajes" table!');
      return;
    }

    final viaje = viajes.first;
    print('Trip details:');
    print('  ID: ${viaje['id']}');
    print('  Codigo: ${viaje['viaje_codigo']}');
    print('  Estado: ${viaje['estado']}');
    print('  Chofer ID: ${viaje['chofer_id']}');

    // 2. Fetch stops for this trip
    final paradas = await client
        .from('paradas')
        .select('*, remitos(*)')
        .eq('viaje_id', viaje['id']);

    print('\nStops in this trip:');
    for (var p in paradas) {
      print('  -------------------------------');
      print('  Stop ID: ${p['id']}');
      print('  Nombre/Ubicacion: ${p['ubicacion'] ?? p['persona_nombre']}');
      print('  Tipo: ${p['tipo']}');
      print('  Estado: ${p['estado']}');
      
      final remitos = p['remitos'] as List? ?? [];
      print('  Remitos count: ${remitos.length}');
      for (var r in remitos) {
        print('    - Remito ID: ${r['id']}, Codigo: ${r['remito_codigo']}, PDF: ${r['pdf_url']}');
      }
    }
    // 3. Fetch charges for this trip
    final cargas = await client
        .from('cargas')
        .select('*, carga_items(*)')
        .eq('viaje_id', viaje['id']);

    print('\nCargas for this trip:');
    print('  Cargas count: ${cargas.length}');
    for (var c in cargas) {
      print('  -------------------------------');
      print('  Carga ID: ${c['id']}');
      print('  Codigo: ${c['carga_codigo']}');
      print('  Estado: ${c['estado']}');
      print('  Items count: ${(c['carga_items'] as List).length}');
      for (var item in (c['carga_items'] as List)) {
        print('    - Item: ${item['producto_codigo']} x ${item['cantidad']}');
      }
    }
  } catch (e, stack) {
    print('❌ Error occurred during diagnosis: $e');
    print(stack);
  }
}
