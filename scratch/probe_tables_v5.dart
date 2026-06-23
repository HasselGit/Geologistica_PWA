import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Probing wide list of potential tables in Supabase ---');
  final potential = [
    'profiles', 'users', 'usuarios', 
    'viajes', 'paradas', 'parada_items', 'remitos', 'pesajes', 
    'vehiculos', 'apicultores', 'necesidades', 'inventario', 'tambores',
    'gastos', 'gasto', 'viaje_gastos', 'cargas', 'carga_items', 'solicitudes', 'rutas', 'productos',
    'remito_items', 'remito_numeradores'
  ];
  
  for (final t in potential) {
    try {
      final res = await client.from(t).select().limit(1);
      print('EXISTS: $t, Rows: ${res.length}, Columns: ${res.isNotEmpty ? res.first.keys.toList() : "Empty table"}');
    } catch (e) {
      if (e.toString().contains('PGRST205')) {
        // Table not found in cache
      } else {
        print('EXISTS (with other error/empty): $t - $e');
      }
    }
  }
}
