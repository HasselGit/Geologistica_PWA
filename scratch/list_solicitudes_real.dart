import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  
  try {
    print('--- OBTENIENDO SOLICITUDES DE LA BASE DE DATOS ---');
    final res = await client.from('solicitudes').select('*, apicultores(nombre, apellido, id)');
    final List<dynamic> solicitudes = res as List;
    print('Cantidad total de solicitudes en DB: ${solicitudes.length}');
    for (var s in solicitudes) {
      print('ID: ${s['id']} | Apicultor: ${s['apicultores']?['nombre']} ${s['apicultores']?['apellido']} (${s['apicultor_id']}) | Producto: ${s['producto']} | Cantidad: ${s['cantidad']} | Estado: ${s['estado']} | Tipo: ${s['tipo']} | Localidad: ${s['localidad']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
