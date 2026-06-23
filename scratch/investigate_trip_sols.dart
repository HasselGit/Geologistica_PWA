import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final tripCode = 'V-1105-925';
  print('INVESTIGATING TRIP: $tripCode');

  // 1. Get the trip
  final trips = await client.from('viajes').select().eq('viaje_codigo', tripCode);
  if (trips.isEmpty) {
    print('Trip not found');
    return;
  }
  final tripId = trips[0]['id'];
  print('Trip ID: $tripId');

  // 2. Get paradas for this trip
  final paradas = await client.from('paradas').select('*, solicitudes(*)').eq('viaje_id', tripId);
  print('Found ${paradas.length} paradas');
  
  for (var p in paradas) {
    print('Parada ID: ${p['id']} | Solicitud: ${p['solicitudes']}');
    if (p['solicitudes'] != null) {
      final sol = p['solicitudes'];
      print('  Solicitud ID: ${sol['id']} | Api ID: ${sol['apicultor_id']} | Estado: ${sol['estado']}');
    }
  }

  // 3. Check if there are any solicitudes that SHOULD be linked but aren't
  // Sometimes they are linked via parada_items or other ways? 
  // User said "2 solicitudes cargas" - maybe they are just linked to paradas.
}
