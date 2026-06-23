import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Probing remitos columns via get_table_columns_info RPC ---');
  try {
    final res = await client.rpc('get_table_columns_info', params: {'table_name': 'remitos'});
    print('Columns of remitos: $res');
  } catch (e) {
    print('RPC failed: $e');
  }

  // We can also try doing a dummy insert with just the columns we know exist:
  // parada_id, viaje_id, pdf_url, fecha, firma_url, persona_nombre, persona_dni
  print('\n--- Testing dummy insert in remitos table ---');
  try {
    // Let us get a valid parada_id and viaje_id first
    final parada = await client.from('paradas').select('id, viaje_id').limit(1).maybeSingle();
    if (parada == null) {
      print('No paradas found to test insert.');
      return;
    }
    
    final paradaId = parada['id'];
    final viajeId = parada['viaje_id'];
    print('Found valid paradaId: $paradaId, viajeId: $viajeId');

    final testData = {
      'parada_id': paradaId,
      'viaje_id': viajeId,
      'pdf_url': 'https://example.com/test.pdf',
      'firma_url': 'https://example.com/test.png',
      'persona_nombre': 'Test Receptor',
      'persona_dni': '12345678',
      'fecha': DateTime.now().toIso8601String(),
    };

    final insertRes = await client.from('remitos').insert(testData).select();
    print('Insert succeeded! Row created: $insertRes');

    // Clean up
    if (insertRes.isNotEmpty) {
      final insertedId = insertRes.first['id'];
      await client.from('remitos').delete().eq('id', insertedId);
      print('Test row cleaned up.');
    }
  } catch (e) {
    print('Insert failed: $e');
  }
}
