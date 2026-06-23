import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Verificando Buckets de Storage (New Key) ---');
  try {
    final buckets = await client.storage.listBuckets();
    print('Buckets encontrados: ${buckets.length}');
    for (var b in buckets) {
      print(' - ID: "${b.id}" (Nombre: "${b.name}", Público: ${b.public})');
    }
  } catch (e) {
    print('Error al listar buckets: $e');
  }
}
