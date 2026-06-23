import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Attempting to insert a row into clientes...');
    final res = await client.from('clientes').insert({
      'cuit': '78965412365',
      'nombre': 'Cliente de Prueba',
    }).select();
    print('Success! Inserted row: $res');
    
    // Clean up
    await client.from('clientes').delete().eq('cuit', '78965412365');
    print('Deleted test row successfully.');
  } catch (e) {
    print('Insert failed: $e');
  }
}
