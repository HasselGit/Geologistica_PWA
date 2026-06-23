import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('--- Paradas y su relación con solicitudes ---');
    final paradas = await client.from('paradas').select('id, viaje_id, solicitud_id, estado, tipo, viajes(viaje_codigo, estado)');
    for (var p in paradas) {
      final viaje = p['viajes'];
      final vCode = viaje != null ? viaje['viaje_codigo'] : 'Desconocido';
      final vState = viaje != null ? viaje['estado'] : 'Desconocido';
      print('Parada ID: ${p['id']}, Viaje: $vCode (Estado: $vState), Solicitud ID: ${p['solicitud_id']}, Estado Parada: ${p['estado']}, Tipo Parada: ${p['tipo']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
