import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Limpiando Cargas de Prueba (TEST-FORM o similares) ---');

  try {
    // 1. Buscar todas las cargas que empiecen con 'TEST-' o 'Test-'
    final response = await client
        .from('cargas')
        .select('id, carga_codigo');

    final List<dynamic> allCargas = response as List<dynamic>;
    print('Total cargas encontradas: ${allCargas.length}');

    int deletedCount = 0;
    for (var carga in allCargas) {
      final codigo = (carga['carga_codigo'] ?? '').toString();
      final codigoUpper = codigo.toUpperCase();
      print('Carga encontrada: $codigo');
      if (codigoUpper.startsWith('TEST-') || codigoUpper.contains('TEST-FORM') || codigoUpper.contains('TEST')) {
        final id = carga['id'];
        print('Eliminando carga de prueba: $codigo (ID: $id)');
        // Eliminar items de carga primero por integridad referencial
        await client.from('carga_items').delete().eq('carga_id', id);
        // Eliminar la carga
        await client.from('cargas').delete().eq('id', id);
        deletedCount++;
      }
    }
    print('Se eliminaron $deletedCount cargas de prueba.');
  } catch (e) {
    print('Error durante la limpieza: $e');
  }
}
