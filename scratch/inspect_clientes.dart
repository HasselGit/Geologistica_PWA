import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('=== CLIENTES ===');
    final clientes = await client.from('clientes').select();
    print('Total Clientes: ${clientes.length}');
    for (var cl in clientes.take(10)) {
      print('Cliente: ${cl['nombre']} | CUIT: ${cl['cuit']} | DNI: ${cl['dni']}');
    }

    print('\n=== APICULTORES ===');
    final apicultores = await client.from('apicultores').select().limit(5);
    for (var ap in apicultores) {
      print('Apicultor: ${ap['nombre']} | DNI: ${ap['dni']} | CUIT: ${ap['cuit']} | ID: ${ap['id']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
