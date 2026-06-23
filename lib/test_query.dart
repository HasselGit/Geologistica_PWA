import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

void main() async {
  print('Iniciando test...');
  // Initialize Supabase in a standalone dart app
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  final client = Supabase.instance.client;
  
  try {
    print('1. Intentando select de viajes...');
    final res = await client.from('viajes').select('*, paradas(*)');
    print('Exito 1! viajes: ${res.length}');
  } catch (e) {
    print('Error 1: $e');
  }

  try {
    print('2. Intentando select simple de viajes...');
    final res = await client.from('viajes').select('*');
    print('Exito 2! viajes: ${res.length}');
  } catch (e) {
    print('Error 2: $e');
  }
  
  try {
    print('3. Intentando select de profiles...');
    final res = await client.from('profiles').select('*');
    print('Exito 3! profiles: ${res.length}');
  } catch (e) {
    print('Error 3: $e');
  }
  
  exit(0);
}
