import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final tripCode = 'V-1105-925';
  final trips = await client.from('viajes').select().eq('viaje_codigo', tripCode);
  final tripId = trips[0]['id'];

  final cargas = await client.from('cargas').select('*, carga_items(*)').eq('viaje_id', tripId);
  print('CARGAS for $tripCode: ${cargas.length}');
  for (var c in cargas) {
    print('Carga ID: ${c['id']} | Estado: ${c['estado']}');
    final items = c['carga_items'] as List;
    for (var it in items) {
       print('  Item: ${it['producto_codigo']} | Cant: ${it['cantidad']}');
    }
  }
}
