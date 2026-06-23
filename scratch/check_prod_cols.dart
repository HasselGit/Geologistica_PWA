import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  try {
    print('Intentando insertar un producto sin nombre...');
    final res = await client.from('productos').insert({
      'descripcion': 'Test Schema',
      'codigo': '999',
      'unidad': 'Uni'
    }).select();
    if (res.isNotEmpty) {
      print('Success! Columns: ${res.first.keys.toList()}');
      await client.from('productos').delete().eq('id', res.first['id']);
    }
  } catch (e) {
    print('Error detectado: $e');
  }
}
