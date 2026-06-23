import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('Iniciando script de eliminación...');
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  final client = Supabase.instance.client;
  
  try {
    print('Buscando al chofer Esteban...');
    final res = await client.from('profiles').select('*').eq('nombre', 'Esteban');
    if (res.isEmpty) {
      print('No se encontró a ningún chofer con el nombre Esteban.');
    } else {
      for (var p in res) {
        print('Chofer encontrado: ${p['id']} - ${p['nombre']} ${p['apellido']}');
        print('Intentando eliminar...');
        try {
          await client.from('profiles').delete().eq('id', p['id']);
          print('Eliminado exitosamente.');
        } catch (e) {
          print('Error al eliminar (puede tener viajes asociados): $e');
          print('Intentando marcarlo como inactivo...');
          await client.from('profiles').update({'puesto': 'Inactivo'}).eq('id', p['id']);
          print('Marcado como inactivo exitosamente.');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
  
  exit(0);
}
