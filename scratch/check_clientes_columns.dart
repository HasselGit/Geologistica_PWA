import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Querying information_schema...');
    final List<dynamic> columns = await client.rpc('get_table_columns', params: {'table_name': 'clientes'});
    print('Columns: $columns');
  } catch (e) {
    print('RPC failed: $e');
    // Fallback: try inserting a row with invalid columns to see the error, or query via custom SQL if we can
    try {
      final res = await client.from('clientes').insert({'non_existent_column': 'test'});
      print('Res: $res');
    } catch (err) {
      print('Insert error (useful to see columns): $err');
    }
  }
}
