import 'package:supabase/supabase.dart';
import 'package:geo_logistica/backend/supabase_service.dart';
import 'package:flutter/widgets.dart';

void main() async {
  // Inicialización básica para Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  final service = SupabaseService();
  print('--- Probando SupabaseService.getViajes() ---');
  try {
    final viajes = await service.getViajes();
    print('Cantidad de viajes retornados: ${viajes.length}');
    for (var v in viajes) {
      print(' - ID: ${v['id']}, Codigo: ${v['viaje_codigo']}, Estado: ${v['estado']}');
    }
  } catch (e) {
    print('Error en getViajes: $e');
  }

  print('\n--- Probando SupabaseService.getProductos() ---');
  try {
    final productos = await service.getProductos();
    print('Cantidad de productos retornados: ${productos.length}');
    for (var p in productos) {
      print(' - Codigo: ${p['codigo']}, Descripcion: ${p['descripcion']}');
    }
  } catch (e) {
    print('Error en getProductos: $e');
  }
}
