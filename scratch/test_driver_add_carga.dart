import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final driverId = 'dc92ea39-a60e-49ef-9ed5-d7d97ba7995a'; // Cristian Muse
  final viajeId = 'efd6d155-eb5c-446c-81ee-decfae697c23'; // Trip V-2805-119

  print('=== SIMULATING DRIVER ADD CARGA ===');
  try {
    // 1. Insert carga
    final formattedCargaCodigo = 'Carga-Test-Driver | Depósito Huinca';
    final cargaInsert = {
      'viaje_id': viajeId,
      'carga_codigo': formattedCargaCodigo,
      'estado': 'Pendiente',
      'created_by': driverId,
    };
    
    print('Inserting into "cargas" with payload: $cargaInsert');
    final res = await client.from('cargas').insert(cargaInsert).select('id').single();
    final newCargaId = res['id'];
    print('✅ Carga inserted successfully! ID: $newCargaId');

    // 2. Insert items
    final List<Map<String, dynamic>> itemsToInsert = [
      {
        'carga_id': newCargaId,
        'producto_codigo': 'CU',
        'cantidad': 125.0,
        'unidad': 'uni',
      }
    ];
    print('Inserting into "carga_items" with payload: $itemsToInsert');
    await client.from('carga_items').insert(itemsToInsert);
    print('✅ Carga items inserted successfully!');

    // 3. Cleanup
    print('Cleaning up test data...');
    await client.from('cargas').delete().eq('id', newCargaId);
    print('✅ Cleanup SUCCEEDED!');
  } catch (e) {
    print('❌ Simulation FAILED: $e');
  }
}
