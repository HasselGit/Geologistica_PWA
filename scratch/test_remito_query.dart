import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('Iniciando test de consulta de remito...');
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  final client = Supabase.instance.client;

  // 1. Intentar obtener una carga
  try {
    final list = await client.from('cargas').select('id, carga_codigo, viaje_id').limit(1);
    if (list.isEmpty) {
      print('No hay cargas en la base de datos');
      exit(0);
    }
    final cargaId = list.first['id'];
    print('ID de carga de prueba: $cargaId');

    print('Probando query con profiles:chofer_id...');
    try {
      final query1 = await client
          .from('cargas')
          .select('*, viaje:viaje_id(*, profiles:chofer_id(nombre, apellido), vehiculos:vehiculo_codigo(*)), carga_items(*)')
          .eq('id', cargaId)
          .maybeSingle();
      print('Éxito con profiles:chofer_id! Datos: $query1');
    } catch (e) {
      print('Fallo con profiles:chofer_id: $e');
    }

    print('Probando query alternativa (consultas separadas)...');
    try {
      final queryCarga = await client
          .from('cargas')
          .select('*, viaje:viaje_id(*, vehiculos:vehiculo_codigo(*)), carga_items(*)')
          .eq('id', cargaId)
          .maybeSingle();
      if (queryCarga != null) {
        print('Carga obtenida. Buscando chofer_id: ${queryCarga['viaje']?['chofer_id']}');
        final choferId = queryCarga['viaje']?['chofer_id'];
        if (choferId != null) {
          final profile = await client.from('profiles').select('nombre, apellido').eq('id', choferId).maybeSingle();
          print('Perfil de chofer obtenido por separado: $profile');
        } else {
          print('El viaje no tiene chofer_id asignado');
        }
      } else {
        print('Carga no encontrada en query de separación');
      }
    } catch (e) {
      print('Fallo en query alternativa: $e');
    }

  } catch (e) {
    print('Error general: $e');
  }

  exit(0);
}
