import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== TESTING EXACT QUERY FROM SERVICE ===');
  try {
    final query = client.from('cargas')
        .select('id, carga_codigo, viaje_id, estado, created_at, updated_at, carga_items(id, producto_codigo, cantidad, unidad)');
    final data = await query.order('created_at', ascending: false);
    print('Query succeeded! Found ${data.length} loads.');
    for (var c in data) {
      print('Load: ID=${c['id']}, Code=${c['carga_codigo']}');
      print('carga_items type: ${c['carga_items'].runtimeType}');
      print('carga_items value: ${c['carga_items']}');
    }
  } catch (e) {
    print('Query failed: $e');
  }
}
