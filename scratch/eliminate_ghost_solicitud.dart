import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final id = '2d1cb2cd-e2d7-4728-b8b3-b67a1d5ae954';
  try {
    print('Intentando marcar la solicitud fantasma $id como Eliminada...');
    final response = await client.from('solicitudes').update({'estado': 'Eliminada'}).eq('id', id).select();
    print('Respuesta del update: $response');
  } catch (e) {
    print('Error al actualizar: $e');
  }
}
