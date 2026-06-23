import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Probing tables...');
    // Testing common variations
    final tests = ['pesajes', 'pesaje', 'registros_pesaje', 'remitos', 'viajes_pesajes'];
    for (var t in tests) {
      try {
        await client.from(t).select().limit(1);
        print('FOUND TABLE: $t');
      } catch (e) {
        // print('NOT FOUND: $t');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
