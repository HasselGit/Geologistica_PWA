import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final id = 'ca453957-dc86-4ffd-875a-224fff70a3f4';
  try {
    print('Intentando eliminar solicitud $id físicamente con cliente anon...');
    final response = await client.from('solicitudes').delete().eq('id', id).select();
    print('Respuesta del delete: $response');
  } catch (e) {
    print('Error al eliminar: $e');
  }
}
