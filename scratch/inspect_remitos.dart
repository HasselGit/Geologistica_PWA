import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Checking all remitos in database...');
    final List<dynamic> remitos = await client.from('remitos').select('id, cliente_cuit, numero_remito');
    print('Total remitos: ${remitos.length}');
    final nonNullRemitos = remitos.where((r) => r['cliente_cuit'] != null).toList();
    print('Remitos with non-null cliente_cuit: ${nonNullRemitos.length}');
    for (var r in nonNullRemitos.take(10)) {
      print('Remito: ${r['numero_remito']} | cliente_cuit: ${r['cliente_cuit']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
