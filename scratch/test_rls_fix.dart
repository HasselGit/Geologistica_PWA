import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando RLS y Esquema ---');

  // 1. Verificar tablas básicas
  final tables = ['profiles', 'vehiculos', 'productos', 'solicitudes', 'viajes', 'rutas', 'paradas', 'parada_items'];
  
  for (var table in tables) {
    try {
      final res = await client.from(table).select().limit(1);
      print('[OK] Tabla "$table" accesible. Filas encontradas: ${res.length}');
      if (res.isNotEmpty) {
        print('     Columnas detectadas: ${res.first.keys.join(", ")}');
      } else {
        // Fetch one row even if it doesn't exist to see keys if possible or just try to select specific columns
        try {
          final cols = await client.from(table).select('*').limit(0);
          // Postgrest might not return keys for 0 rows.
          print('     Tabla vacía.');
        } catch (_) {}
      }
    } catch (e) {
      print('[ERROR] Error al acceder a "$table": $e');
    }
  }

  // 2. Probar inserción en RUTAS para verificar RLS
  print('\n--- Probando Inserción en "rutas" ---');
  try {
    // Necesitamos un viaje_id válido para la FK
    final viaje = await client.from('viajes').select('id').limit(1).maybeSingle();
    if (viaje == null) {
      print('[INFO] No hay viajes para probar inserción en rutas.');
    } else {
      final viajeId = viaje['id'];
      final tempRutaCode = 'TEST-RLS-${DateTime.now().millisecondsSinceEpoch}';
      
      final insertRes = await client.from('rutas').insert({
        'viaje_id': viajeId,
        'ruta_codigo': tempRutaCode,
        'estado': 'Pendiente',
        'fecha_planificada': DateTime.now().toIso8601String(),
      }).select().single();
      
      print('[OK] Inserción en "rutas" EXITOSA. RLS parece estar corregido.');
      
      // Limpiar prueba
      await client.from('rutas').delete().eq('id', insertRes['id']);
      print('[OK] Registro de prueba eliminado.');
    }
  } catch (e) {
    print('[FAIL] La inserción en "rutas" falló: $e');
    print('       Esto confirma que el RLS sigue bloqueando o hay un error de esquema.');
  }

  // 3. Verificar paradas
  print('\n--- Verificando columnas críticas en "paradas" ---');
  try {
    await client.from('paradas').select('id, viaje_id, ruta_id, ubicacion, estado').limit(1);
    print('[OK] Columnas de "paradas" correctas (incluye ruta_id).');
  } catch (e) {
    print('[ERROR] Fallo en columnas de "paradas": $e');
  }
}
