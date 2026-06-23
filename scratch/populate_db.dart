import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  const choferId = 'd96485ce-0003-48e9-be14-b5de638063b4'; // Mauricio Perez
  // Use vehiculo_codigo values that already satisfy FK constraint in DB
  const vehiculo1 = 'TRK-001';
  const vehiculo2 = 'MB1634';

  // ─── Cleanup ──────────────────────────────────────────────────
  print('Limpiando datos GEO-2026 anteriores...');
  try {
    final oldViajes = await supabase.from('viajes').select('id').like('viaje_codigo', 'GEO-2026-%') as List;
    for (final v in oldViajes) {
      await supabase.from('paradas').delete().eq('viaje_id', v['id']);
    }
    await supabase.from('viajes').delete().like('viaje_codigo', 'GEO-2026-%');
    print('Limpieza completada.');
  } catch (e) { print('Nota limpieza: $e'); }

  // ─── VIAJES ─────────────────────────────────────────────────────
  print('Insertando viajes...');
  final v1 = await supabase.from('viajes').insert({
    'viaje_codigo': 'GEO-2026-001', 'chofer_id': choferId,
    'vehiculo_codigo': vehiculo1, 'estado': 'Planificado',
  }).select().single() as Map<String, dynamic>;

  final v2 = await supabase.from('viajes').insert({
    'viaje_codigo': 'GEO-2026-002', 'chofer_id': choferId,
    'vehiculo_codigo': vehiculo2, 'estado': 'En Proceso',
  }).select().single() as Map<String, dynamic>;

  final v3 = await supabase.from('viajes').insert({
    'viaje_codigo': 'GEO-2026-003', 'chofer_id': choferId,
    'vehiculo_codigo': vehiculo1, 'estado': 'Terminado',
  }).select().single() as Map<String, dynamic>;

  print('Viajes creados: ${v1['id']}, ${v2['id']}, ${v3['id']}');

  // ─── PARADAS ────────────────────────────────────────────────────
  print('Insertando paradas...');

  // Viaje 01 — PLANIFICADO: 2 Recolecciones + 1 Distribución
  await supabase.from('paradas').insert({'viaje_id': v1['id'], 'orden_secuencia': 1, 'tipo': 'Recoleccion', 'localidad': 'Olavarría', 'persona_nombre': 'Juan Pérez Apicultor', 'cliente_cuit': '20-29876543-2', 'estado': 'pendiente'});
  await supabase.from('paradas').insert({'viaje_id': v1['id'], 'orden_secuencia': 2, 'tipo': 'Recoleccion', 'localidad': 'Olavarría', 'persona_nombre': 'Familia Rodríguez Apícola', 'cliente_cuit': '27-33445566-0', 'estado': 'pendiente'});
  await supabase.from('paradas').insert({'viaje_id': v1['id'], 'orden_secuencia': 3, 'tipo': 'Distribucion', 'localidad': 'Azul', 'persona_nombre': 'Depósito Central Azul', 'cliente_cuit': '30-71234567-8', 'estado': 'pendiente'});

  // Viaje 02 — EN PROCESO: 3 Recolecciones + 1 Distribución
  await supabase.from('paradas').insert({'viaje_id': v2['id'], 'orden_secuencia': 1, 'tipo': 'Recoleccion', 'localidad': 'Balcarce', 'persona_nombre': 'María Gómez Apiario', 'cliente_cuit': '27-98765432-1', 'estado': 'completada'});
  await supabase.from('paradas').insert({'viaje_id': v2['id'], 'orden_secuencia': 2, 'tipo': 'Recoleccion', 'localidad': 'Balcarce', 'persona_nombre': 'Roberto Sánchez Apiario', 'cliente_cuit': '20-11223344-5', 'estado': 'completada'});
  await supabase.from('paradas').insert({'viaje_id': v2['id'], 'orden_secuencia': 3, 'tipo': 'Recoleccion', 'localidad': 'Mar del Plata', 'persona_nombre': 'Cooperativa Apícola Sur', 'cliente_cuit': '30-55667788-9', 'estado': 'pendiente'});
  await supabase.from('paradas').insert({'viaje_id': v2['id'], 'orden_secuencia': 4, 'tipo': 'Distribucion', 'localidad': 'Mar del Plata', 'persona_nombre': 'Planta Industrial GeoMiel', 'cliente_cuit': '30-77889900-1', 'estado': 'pendiente'});

  // Viaje 03 — TERMINADO: 2 Recolecciones
  await supabase.from('paradas').insert({'viaje_id': v3['id'], 'orden_secuencia': 1, 'tipo': 'Recoleccion', 'localidad': 'Tandil', 'persona_nombre': 'Apiario Los Álamos', 'cliente_cuit': '20-44556677-8', 'estado': 'completada'});
  await supabase.from('paradas').insert({'viaje_id': v3['id'], 'orden_secuencia': 2, 'tipo': 'Recoleccion', 'localidad': 'Tandil', 'persona_nombre': 'Carlos Mendez Apicultor', 'cliente_cuit': '20-66778899-0', 'estado': 'completada'});

  print('✅ Base de datos poblada correctamente.');
  print('Iniciá sesión como mperez@geomiel.com / mperez para ver los datos.');
}
