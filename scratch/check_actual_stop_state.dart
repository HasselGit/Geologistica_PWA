import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Search Parada 81c176af-6e59-4684-8333-4a03f1381c34 ---');
    final p = await client.from('paradas').select().eq('id', '81c176af-6e59-4684-8333-4a03f1381c34').maybeSingle();
    print('Parada row: $p');
  } catch (e) {
    print('Error: $e');
  }
}
