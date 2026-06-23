import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== TESTING VIAJES FILTER IN GASTOS ===');
  try {
    var query = client
        .from('viajes')
        .select('id, viaje_codigo, estado, chofer_id')
        .filter('estado', 'in', ['En Proceso', 'En Curso', 'Terminado'])
        .order('fecha', ascending: false)
        .limit(40);
        
    final res = await query;
    print('✅ Filter query SUCCEEDED! Retrieved ${res.length} rows.');
  } catch (e) {
    print('❌ Filter query FAILED: $e');
  }

  print('\n=== TESTING CHOFER VIAJES FILTER IN GASTOS ===');
  try {
    final userId = 'dc92ea39-a60e-49ef-9ed5-d7d97ba7995a'; // Cristian Muse
    var query = client
        .from('viajes')
        .select('id, viaje_codigo, estado, chofer_id')
        .filter('estado', 'in', ['En Proceso', 'En Curso'])
        .eq('chofer_id', userId)
        .order('fecha', ascending: false)
        .limit(20);
        
    final res = await query;
    print('✅ Chofer filter query SUCCEEDED! Retrieved ${res.length} rows.');
  } catch (e) {
    print('❌ Chofer filter query FAILED: $e');
  }
}
