import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Solicitudes en base de datos ---');
    final response = await client.from('solicitudes').select('id, estado, producto, cantidad, solicitud_codigo, apicultores(nombre)');
    for (var r in response) {
      final apicultor = r['apicultores'];
      final apName = apicultor != null ? apicultor['nombre'] : 'Desconocido';
      print('ID: ${r['id']}, Code: ${r['solicitud_codigo']}, Apicultor: $apName, Producto: ${r['producto']}, Estado: ${r['estado']}, Qty: ${r['cantidad']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
