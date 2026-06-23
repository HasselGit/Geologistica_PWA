import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== SIMULATING CARGANDO POR CAROLINA MERLO ===');
  try {
    // 1. Fetch the loads for Voyage V-2105-906 (ebcbcae8-e802-4733-9e0e-639d3861f29c)
    final cargas = await client.from('cargas')
        .select('id, carga_codigo, estado')
        .eq('viaje_id', 'ebcbcae8-e802-4733-9e0e-639d3861f29c');
    
    print('Loads for V-2105-906:');
    for (var c in cargas) {
      print('  Carga: ${c['carga_codigo']} - ID: ${c['id']} - Estado: ${c['estado']}');
    }

    if (cargas.isNotEmpty) {
      final firstCarga = cargas.first;
      print('\n2. Testing state update of ${firstCarga['carga_codigo']} to En Proceso...');
      await client.from('cargas').update({
        'estado': 'En Proceso',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', firstCarga['id']);
      print('Update succeeded!');

      // Reset it back to Pendiente to avoid changing persistent test data yet
      await client.from('cargas').update({
        'estado': 'Pendiente',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', firstCarga['id']);
      print('Reset succeeded!');
    }
  } catch (e) {
    print('Failed: $e');
  }
}
