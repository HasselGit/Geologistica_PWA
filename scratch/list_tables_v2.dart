import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Listing all tables by probing common names...');
    final potential = ['pesajes', 'pesaje', 'remitos', 'remito', 'items', 'item', 'apicultores', 'apicultor'];
    for (final t in potential) {
      try {
        await client.from(t).select().limit(0);
        print('FOUND: $t');
      } catch (_) {}
    }
  } catch (e) {
    print('Error: $e');
  }
}
