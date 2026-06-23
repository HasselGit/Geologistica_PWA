import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final tables = ['profiles', 'vehiculos', 'apicultores', 'viajes', 'paradas', 'necesidades'];

  for (final table in tables) {
    try {
      print('\n--- Table: $table ---');
      final data = await client.from(table).select().limit(1);
      if (data.isNotEmpty) {
        print('Columns: ${data[0].keys.toList()}');
      } else {
        print('Table empty, trying RPC or just insert/rollback if possible (not possible here easily).');
      }
    } catch (e) {
      print('Error checking $table: $e');
    }
  }
}
