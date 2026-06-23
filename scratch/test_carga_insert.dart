import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final driverId = 'dc92ea39-a60e-49ef-9ed5-d7d97ba7995a'; // Cristian Muse
  final viajeId = 'efd6d155-eb5c-446c-81ee-decfae697c23'; // Trip V-2805-119

  print('=== TEST CARGA INSERT FOR DRIVER ===');
  try {
    // 1. Insert carga
    final cargaInsert = {
      'viaje_id': viajeId,
      'carga_codigo': 'Test-Carga-Chofer',
      'estado': 'Pendiente',
      'deposito_origen': 'Depósito Huinca',
      'created_by': driverId,
    };
    
    print('Attempting to insert into "cargas"...');
    final res = await client.from('cargas').insert(cargaInsert).select('id').single();
    final newCargaId = res['id'];
    print('✅ Carga inserted successfully! ID: $newCargaId');

    // 2. Insert items
    final itemInsert = {
      'carga_id': newCargaId,
      'producto_codigo': 'CU',
      'cantidad': 125.0,
      'unidad': 'uni',
    };
    print('Attempting to insert into "carga_items"...');
    await client.from('carga_items').insert(itemInsert);
    print('✅ Carga item inserted successfully!');

    // 3. Cleanup test data
    print('Cleaning up test data...');
    await client.from('cargas').delete().eq('id', newCargaId);
    print('✅ Test data cleaned up.');
  } catch (e) {
    print('❌ Failed: $e');
  }
}
