import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('=== REMITOS COLUMNS ===');
    // We can do a select limit 0 to see headers or query pg_attribute if we had raw SQL.
    // Let's do a select from pg_catalog or query through RPC if available, or just maybeSingle of remitos
    final remitos = await client.from('remitos').select().limit(1);
    if (remitos.isNotEmpty) {
      print('Remitos columns: ${remitos[0].keys.toList()}');
      print('Sample Remito: ${remitos[0]}');
    } else {
      print('Remitos table is empty.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
