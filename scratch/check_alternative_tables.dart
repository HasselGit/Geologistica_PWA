import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final tables = ['apicultor', 'solicitud', 'solicitudes', 'necesidad'];

  for (final table in tables) {
    try {
      print('\n--- Checking: $table ---');
      final data = await client.from(table).select().limit(1);
      print('Table $table exists. Columns: ${data.isNotEmpty ? data[0].keys.toList() : "Empty table"}');
    } catch (e) {
      print('Table $table NOT found or error: $e');
    }
  }
}
