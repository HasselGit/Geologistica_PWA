import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Auditando tabla paradas...');
    final p = await client.from('paradas').select('*').limit(1);
    if (p.isNotEmpty) print('Columnas paradas: ${p.first.keys.toList()}');

    print('Auditando tabla parada_items...');
    final pi = await client.from('parada_items').select('*').limit(1);
    if (pi.isNotEmpty) print('Columnas parada_items: ${pi.first.keys.toList()}');

    print('Auditando tabla solicitudes...');
    final s = await client.from('solicitudes').select('*').limit(1);
    if (s.isNotEmpty) print('Columnas solicitudes: ${s.first.keys.toList()}');

  } catch (e) {
    print('ERROR: $e');
  }
}
