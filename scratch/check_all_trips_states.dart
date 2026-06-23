import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== ALL VIAJES AND CARGAS IN DB ===');
  try {
    final res = await client.from('viajes').select('id, viaje_codigo, estado, cargas(id, carga_codigo, estado)');
    print('Total viajes: ${res.length}');
    for (var v in res) {
      print('Viaje: ${v['viaje_codigo']} - Estado: ${v['estado']}');
      final cargas = v['cargas'] as List? ?? [];
      print('  Cargas (${cargas.length}):');
      for (var c in cargas) {
        print('    - Carga: ${c['carga_codigo']} - Estado: ${c['estado']}');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
