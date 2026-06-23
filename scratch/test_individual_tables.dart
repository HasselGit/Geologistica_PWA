import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final tables = [
    'profiles', 'viajes', 'paradas', 'parada_items', 'remitos', 'pesajes', 
    'vehiculos', 'apicultores', 'solicitudes', 'rutas', 'productos', 'gastos', 
    'cargas', 'carga_items', 'necesidades'
  ];

  for (final t in tables) {
    try {
      final res = await client.from(t).select().limit(1);
      print('[OK] Table "$t" is fully accessible. Rows: ${res.length}');
    } catch (e) {
      print('[ERR] Table "$t" failed: $e');
    }
  }
}
