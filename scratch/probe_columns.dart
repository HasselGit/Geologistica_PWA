import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final List<String> candidates = ['dni', 'documento', 'renapa', 'apicultor_codigo', 'codigo'];
  
  for (final col in candidates) {
    try {
      final res = await client.from('apicultores').select(col).limit(1);
      print('Column $col EXISTS: $res');
    } catch (e) {
      print('Column $col DOES NOT EXIST');
    }
  }
}
