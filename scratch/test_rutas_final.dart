import 'package:supabase/supabase.dart';

void main() async {
  print('--- TEST FINAL: VALIDANDO COLUMNAS DE RUTAS ---');
  
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Insertando en "rutas" con campos de la App (sin ID manual)...');
    
    // Probamos con los campos que realmente usa el servicio
    final response = await client.from('rutas').insert({
      'estado': 'Pendiente',
      'fecha_planificada': DateTime.now().toIso8601String(),
    }).select('id').single();

    print('✅ ¡ÉXITO TOTAL! Supabase generó el ID: ${response['id']}');
    
    // Limpieza
    await client.from('rutas').delete().eq('id', response['id']);
    print('Base de datos confirmada y limpia.');
    
  } catch (e) {
    print('❌ ERROR EN TEST: $e');
    print('\nSugerencia: Si falla por "viaje_id" es normal porque es obligatorio, pero si el error NO es sobre el campo "id", entonces el problema principal está resuelto.');
  }
}
