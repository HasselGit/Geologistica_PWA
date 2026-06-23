import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Querying one row from paradas table...');
    final paradas = await client
        .from('paradas')
        .select('*')
        .eq('id', '3e804e2d-84ce-43e0-be9a-0a266536da9e')
        .maybeSingle();
    if (paradas != null) {
      print('Row keys: ${paradas.keys.toList()}');
      print('Values: $paradas');
    } else {
      final paradas2 = await client.from('paradas').select('*').limit(1);
      if (paradas2.isNotEmpty) {
        print('Row keys: ${paradas2.first.keys.toList()}');
        print('Values: ${paradas2.first}');
      } else {
        print('Table paradas is empty.');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
