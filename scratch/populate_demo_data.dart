import 'package:supabase/supabase.dart';

void main() async {
  print('--- POBLANDO DATOS DE DEMOSTRACIÓN PROFESIONALES ---');
  
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    // 1. Buscar un chofer (Mauricio Perez o similar)
    final profiles = await client.from('profiles').select().eq('puesto', 'Chofer');
    if (profiles.isEmpty) {
      print('No se encontraron choferes. Abortando.');
      return;
    }
    final choferId = profiles.first['id'];
    final choferNombre = profiles.first['nombre'];
    print('Usando Chofer: $choferNombre ($choferId)');

    // 2. Crear Viaje 1: General Pico -> Del Campillo -> Huinca Renancó
    final viaje1 = await client.from('viajes').insert({
      'viaje_codigo': 'PICO-SUR-001',
      'chofer_id': choferId,
      'vehiculo_codigo': 'MB-1634',
      'estado': 'En Proceso',
      'fecha': DateTime.now().toIso8601String(),
      // 'descripcion' eliminada por no existir en el esquema
    }).select().single();

    final v1Id = viaje1['id'];

    // Paradas Viaje 1
    await client.from('paradas').insert([
      {
        'viaje_id': v1Id,
        'ubicacion': 'Centro de Acopio General Pico',
        'localidad': 'General Pico, LP',
        'tipo_operacion': 'Salida',
        'estado': 'Completada',
        'orden_secuencia': 1,
      },
      {
        'viaje_id': v1Id,
        'ubicacion': 'Apícola Del Campillo',
        'localidad': 'Del Campillo, CB',
        'tipo_operacion': 'Recolección',
        'estado': 'Pendiente',
        'orden_secuencia': 2,
      },
      {
        'viaje_id': v1Id,
        'ubicacion': 'Cooperativa Huinca',
        'localidad': 'Huinca Renancó, CB',
        'tipo_operacion': 'Recolección',
        'estado': 'Pendiente',
        'orden_secuencia': 3,
      }
    ]);

    // 3. Crear Viaje 2: General Pico -> Trenque Lauquen -> Huanguelen
    final viaje2 = await client.from('viajes').insert({
      'viaje_codigo': 'PICO-OESTE-002',
      'chofer_id': choferId,
      'vehiculo_codigo': 'TRK-001',
      'estado': 'Planificado',
      'fecha': DateTime.now().add(Duration(days: 2)).toIso8601String(),
    }).select().single();

    final v2Id = viaje2['id'];

    // Paradas Viaje 2
    await client.from('paradas').insert([
      {
        'viaje_id': v2Id,
        'ubicacion': 'General Pico Base',
        'localidad': 'General Pico, LP',
        'tipo_operacion': 'Carga',
        'estado': 'Pendiente',
        'orden_secuencia': 1,
      },
      {
        'viaje_id': v2Id,
        'ubicacion': 'Apicultor Trenque',
        'localidad': 'Trenque Lauquen, BA',
        'tipo_operacion': 'Distribución',
        'estado': 'Pendiente',
        'orden_secuencia': 2,
      },
      {
        'viaje_id': v2Id,
        'ubicacion': 'Miel Huanguelen',
        'localidad': 'Huanguelén, BA',
        'tipo_operacion': 'Recolección',
        'estado': 'Pendiente',
        'orden_secuencia': 3,
      }
    ]);

    print('--- DATOS POBLADOS EXITOSAMENTE ---');
    print('Viajes creados: PICO-SUR-001 y PICO-OESTE-002');
    
  } catch (e) {
    print('Error poblando datos: $e');
  }
}
