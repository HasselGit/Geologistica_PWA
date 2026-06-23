import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Search Viaje ---');
    final viajes = await client.from('viajes').select().eq('viaje_codigo', 'V-2805-373');
    if (viajes.isEmpty) {
      print('No viaje found');
      return;
    }
    final v = viajes.first;
    print('Viaje: $v');

    print('--- Search Paradas ---');
    final paradas = await client.from('paradas').select().eq('viaje_id', v['id']);
    for (var p in paradas) {
      print('Parada: $p');
      if (p['solicitud_id'] != null) {
        final sol = await client.from('solicitudes').select().eq('id', p['solicitud_id']).maybeSingle();
        print('  Solicitud: $sol');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
