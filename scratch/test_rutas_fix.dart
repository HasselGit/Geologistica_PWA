import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('--- TEST DE INSERCIÓN EN RUTAS ---');
  
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final client = Supabase.instance.client;

  try {
    print('Intentando insertar en tabla "rutas" sin ID (usando DEFAULT de DB)...');
    
    // Insertamos solo el viaje_id (necesitas un ID de viaje existente o null si lo permite)
    // Para este test, intentaremos insertar una fila con datos mínimos
    final response = await client.from('rutas').insert({
      'orden_secuencia': 999,
      'tipo': 'TEST_SYNC',
      'localidad': 'TEST_CITY',
    }).select();

    print('✅ ¡ÉXITO! Supabase generó el ID correctamente: ${response[0]['id']}');
    
    // Limpiamos el test
    await client.from('rutas').delete().eq('id', response[0]['id']);
    print('Test finalizado y limpiado.');
    
  } catch (e) {
    print('❌ ERROR EN TEST: $e');
  }
}
