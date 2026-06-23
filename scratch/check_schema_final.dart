import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- VIAJES ---');
    final v = await client.from('viajes').select().limit(1);
    if (v.isNotEmpty) print('Viajes: ${v[0].keys.toList()}');
    else print('Viajes empty');

    print('\n--- PARADAS ---');
    final p = await client.from('paradas').select().limit(1);
    if (p.isNotEmpty) print('Paradas: ${p[0].keys.toList()}');
    else print('Paradas empty');

    print('\n--- SOLICITUDES ---');
    final s = await client.from('solicitudes').select().limit(1);
    if (s.isNotEmpty) print('Solicitudes: ${s[0].keys.toList()}');
    else print('Solicitudes empty');

  } catch (e) {
    print('Error: $e');
  }
}
