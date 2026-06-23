import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Auditando tabla remitos...');
    final r = await client.from('remitos').select('*').limit(1);
    if (r.isNotEmpty) print('Columnas remitos: ${r.first.keys.toList()}');

    print('Auditando tabla cargas...');
    final c = await client.from('cargas').select('*').limit(1);
    if (c.isNotEmpty) print('Columnas cargas: ${c.first.keys.toList()}');

  } catch (e) {
    print('ERROR: $e');
  }
}
