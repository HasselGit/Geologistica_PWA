import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final driverId = 'dc92ea39-a60e-49ef-9ed5-d7d97ba7995a'; // Cristian Muse
  final viajeId = 'efd6d155-eb5c-446c-81ee-decfae697c23'; // Trip V-2805-119

  print('=== TEST GASTO INSERT ===');
  try {
    final gastoInsert = {
      'tipo_gasto': 'Combustible',
      'importe': 123000.0,
      'descripcion': 'Litros: 85.0 L\nTest gasto descripcion\n[Registrado por: Cristian Muse (Chofer)]',
      'nro_comprobante': '01-456',
      'forma_pago': 'Efectivo',
      'viaje_id': viajeId,
      'fecha': DateTime.now().toIso8601String(),
      'chofer_id': driverId,
    };

    print('Attempting to insert into "gastos"...');
    final res = await client.from('gastos').insert(gastoInsert).select('id').single();
    final newGastoId = res['id'];
    print('✅ Gasto inserted successfully! ID: $newGastoId');

    // Cleanup
    print('Cleaning up test data...');
    await client.from('gastos').delete().eq('id', newGastoId);
    print('✅ Test data cleaned up.');
  } catch (e) {
    print('❌ Failed: $e');
  }
}
