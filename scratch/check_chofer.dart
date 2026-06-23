import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('Initializing Supabase connection...');
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  final client = Supabase.instance.client;
  
  try {
    print('Querying profile for Cristian Muse...');
    final List<dynamic> profiles = await client.from('profiles').select('*');
    for (var p in profiles) {
      final name = '${p['nombre']} ${p['apellido']}'.toLowerCase();
      final email = (p['email'] ?? '').toString().toLowerCase();
      if (name.contains('cristian') || name.contains('muse') || email.contains('cmuse')) {
        print('FOUND PROFILE:');
        print('ID (UUID): ${p['id']}');
        print('Nombre: ${p['nombre']}');
        print('Apellido: ${p['apellido']}');
        print('Email: ${p['email']}');
        print('Puesto: ${p['puesto']}');
        print('Contrasena: ${p['contrasena']}');
        print('-----------------------------------------');
      }
    }
    
    print('Querying active viajes...');
    final List<dynamic> viajes = await client.from('viajes').select('id, viaje_codigo, chofer_id, estado');
    print('Total viajes: ${viajes.length}');
    for (var v in viajes) {
      print('Viaje: ${v['viaje_codigo']} (Estado: ${v['estado']}, Chofer ID: ${v['chofer_id']})');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  exit(0);
}
