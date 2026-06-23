import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Remitos en base de datos ---');
    final response = await client.from('remitos').select('*');
    for (var r in response) {
      print('ID: ${r['id']}, Parada ID: ${r['parada_id']}, Numero: ${r['numero_remito']}, Solicitud ID: ${r['solicitud_id']}, Carga/Cant: ${r['cantidad_cargada']}, Bultos/Tambores: ${r['tambores_cantidad']}, Producto: ${r['producto']}, Tipo: ${r['tipo_remito']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
