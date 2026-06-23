import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('--- Iniciando Limpieza Profunda de Viajes ---');
  
  // Inicialización con Supabase (Usando la instancia activa del proyecto)
  final client = Supabase.instance.client;

  try {
    // 1. Borrar items de paradas
    print('Borrando parada_items...');
    await client.from('parada_items').delete().neq('id', '00000000-0000-0000-0000-000000000000');

    // 2. Borrar paradas
    print('Borrando paradas...');
    await client.from('paradas').delete().neq('id', '00000000-0000-0000-0000-000000000000');

    // 3. Borrar rutas
    print('Borrando rutas...');
    await client.from('rutas').delete().neq('id', '00000000-0000-0000-0000-000000000000');

    // 4. Borrar gastos vinculados a viajes
    print('Borrando gastos de viajes...');
    await client.from('gastos').delete().not('viaje_id', 'is', null);

    // 5. Borrar viajes
    print('Borrando viajes...');
    await client.from('viajes').delete().neq('id', '00000000-0000-0000-0000-000000000000');

    // 6. Resetear solicitudes a 'Pendiente' para que vuelvan a estar disponibles
    print('Reseteando solicitudes a Pendiente...');
    await client.from('solicitudes').update({'estado': 'Pendiente'}).neq('id', '00000000-0000-0000-0000-000000000000');

    print('--- LIMPIEZA COMPLETADA ---');
    exit(0);
  } catch (e) {
    print('Error durante la limpieza: $e');
    exit(1);
  }
}
