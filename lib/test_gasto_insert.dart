import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('Iniciando test de inserción de gasto para Cristian Muse...');
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  final client = Supabase.instance.client;
  
  final cristianMuseId = 'dc92ea39-a60e-49ef-9ed5-d7d97ba7995a';
  final activeTripId = 'efd6d155-eb5c-446c-81ee-decfae697c23';

  try {
    print('Intentando insertar gasto...');
    final response = await client.from('gastos').insert({
      'tipo_gasto': 'Peaje',
      'importe': 1500.0,
      'cantidad_litros': null,
      'descripcion': 'Test de gasto para Cristian Muse',
      'nro_comprobante': 'TEST-123',
      'forma_pago': 'Efectivo',
      'viaje_id': activeTripId,
      'fecha': DateTime.now().toIso8601String(),
      'chofer_id': cristianMuseId,
      'comprobante_url': null,
    }).select();
    
    print('Éxito! Gasto insertado: $response');
  } catch (e) {
    print('ERROR AL INSERTAR GASTO: $e');
  }
  
  exit(0);
}
