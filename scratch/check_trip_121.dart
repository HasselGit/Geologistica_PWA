import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final tripCode = 'V-1105-121';
  print('CHECKING TRIP: $tripCode');

  final trips = await client.from('viajes').select().eq('viaje_codigo', tripCode);
  if (trips.isEmpty) {
    print('Trip not found');
    return;
  }
  final tripId = trips[0]['id'];

  final paradas = await client.from('paradas').select().eq('viaje_id', tripId);
  print('Paradas for $tripCode: ${paradas.length}');
  for (var p in paradas) {
    print('Parada: ${p['id']} | Solicitud ID: ${p['solicitud_id']}');
  }
}
