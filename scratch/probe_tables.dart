import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Testing common table names...');
    final tables = ['profiles', 'users', 'usuarios', 'viajes', 'paradas', 'parada_items', 'necesidades', 'vehiculos', 'choferes'];
    for (final t in tables) {
      try {
        final data = await client.from(t).select().limit(0);
        print('SUCCESS: $t exists');
      } catch (e) {
        print('FAILED: $t (${e.toString().split('\n').first})');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
