import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final email = 'mparedes@geomiel.com';
  final pass = 'mparedes';

  print('--- Simulando Login para $email ---');
  try {
    final response = await client.from('profiles')
        .select()
        .eq('email', email)
        .eq('contrasena', pass)
        .maybeSingle();
    
    if (response == null) {
      print('RESULTADO: No se encontró el perfil (maybeSingle retornó null)');
      
      // Intento alternativo: buscar solo por email
      final checkEmail = await client.from('profiles').select('email').eq('email', email).maybeSingle();
      if (checkEmail == null) {
        print('DIAGNÓSTICO: Ni siquiera puedo encontrar el EMAIL. Probablemente RLS bloquea la búsqueda.');
      } else {
        print('DIAGNÓSTICO: El email EXISTE, pero la contraseña no coincide o algo bloquea la lectura de esa columna.');
      }
    } else {
      print('RESULTADO: ¡Login exitoso en el script! Datos: $response');
    }
  } catch (e) {
    print('ERROR CRÍTICO: $e');
  }
}
