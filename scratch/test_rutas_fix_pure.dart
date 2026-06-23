import 'package:supabase/supabase.dart';

void main() async {
  print('--- TEST DE INSERCIÓN EN RUTAS (PURO DART) ---');
  
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Insertando en "rutas" para validar IDs automáticos...');
    
    final response = await client.from('rutas').insert({
      'orden_secuencia': 888,
      'tipo': 'TEST_UUID_FIX',
      'localidad': 'VERIFICACION',
    }).select();

    if (response.isNotEmpty) {
      print('✅ ¡CONFIRMADO! Supabase generó el ID: ${response[0]['id']}');
      
      // Limpieza
      await client.from('rutas').delete().eq('id', response[0]['id']);
      print('Registro de prueba eliminado.');
    } else {
      print('❌ La respuesta fue vacía.');
    }
    
  } catch (e) {
    print('❌ ERROR EN TEST: $e');
  }
}
