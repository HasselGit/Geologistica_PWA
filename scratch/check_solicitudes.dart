import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('Iniciando verificación...');
  Supabase.initialize(
    url: 'https://pgtwhqypohkgrvyxunsq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBndHdocXlwb2hncnZ5eHVuc3EiLCJyb2xlIjoiYW5vbiIsImlhdCI6MTcxNDkxNTYzOCwiZXhwIjoyMDI5NDkxNjM4fQ.aHq2v3_8W6xW7Z3b-5L1N4Xp3X3_5X3_5X3_5X3_5X3',
  );
  
  final client = Supabase.instance.client;
  try {
    final sols = await client.from('solicitudes').select('id, apicultor_id, producto, cantidad, estado').limit(10);
    print('Muestra de solicitudes:');
    for (var s in sols) {
      print('Solicitud ID: ${s['id']}, apicultor_id: ${s['apicultor_id']}, producto: ${s['producto']}, estado: ${s['estado']}');
    }
    
    final apis = await client.from('apicultores').select('id, nombre').limit(5);
    print('\nMuestra de apicultores:');
    for (var a in apis) {
      print('Apicultor ID: ${a['id']}, nombre: ${a['nombre']}');
    }
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
