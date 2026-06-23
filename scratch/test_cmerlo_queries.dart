import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== PROBANDO COMO CAROLINA MERLO ===');
  try {
    print('Iniciando sesión como cmerlo@geomiel.com...');
    final authRes = await client.auth.signInWithPassword(email: 'cmerlo@geomiel.com', password: 'cmerlo');
    final user = authRes.user;
    if (user == null) {
      print('Fallo al iniciar sesión.');
      return;
    }
    print('Sesión iniciada. ID de usuario: ${user.id}');

    print('\n1. Consultando viajes pendientes (como Carolina)...');
    try {
      final viajes = await client
          .from('viajes')
          .select('*, paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores), cargas(id, carga_codigo, estado, carga_items(*))')
          .eq('estado', 'Pendiente')
          .order('fecha', ascending: true);
      print('Viajes encontrados: ${viajes.length}');
      for (var v in viajes) {
        print('  Viaje: ${v['viaje_codigo']} (Estado: ${v['estado']})');
      }
    } catch (e) {
      print('Error consultando viajes: $e');
    }

    print('\n2. Consultando perfiles (como Carolina)...');
    try {
      final profiles = await client.from('profiles').select('id, nombre, apellido').limit(5);
      print('Perfiles encontrados: ${profiles.length}');
    } catch (e) {
      print('Error consultando perfiles: $e');
    }

    print('\n3. Consultando cargas (como Carolina)...');
    try {
      final cargas = await client.from('cargas').select('*');
      print('Cargas encontradas: ${cargas.length}');
    } catch (e) {
      print('Error consultando cargas: $e');
    }

    print('\n4. Cerrando sesión...');
    await client.auth.signOut();
  } catch (e) {
    print('Error general: $e');
  }
}
