import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  try {
    print('Intentando insertar un viaje de prueba...');
    final res = await client.from('viajes').insert({
      'viaje_codigo': 'TEST-FIX',
      'estado': 'Planificado',
      'descripcion': 'Prueba de corrección de error p.rol',
      'fecha': DateTime.now().toIso8601String(),
    }).select();
    print('Inserción exitosa: $res');
    // Limpiar
    if (res.isNotEmpty) {
      await client.from('viajes').delete().eq('id', res.first['id']);
    }
  } catch (e) {
    print('Error detectado: $e');
  }
}
