import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Probe Paradas ---');
    final p = await client.from('paradas').select().limit(1);
    print(p);

    print('--- Probe Solicitudes ---');
    final s = await client.from('solicitudes').select().limit(1);
    print(s);

    print('--- Probe Pesajes ---');
    final pe = await client.from('pesajes').select().limit(1);
    print(pe);

    print('--- Probe Remitos ---');
    final r = await client.from('remitos').select().limit(1);
    print(r);
  } catch (e) {
    print('Error: $e');
  }
}
