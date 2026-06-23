import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final email = 'mperez@geomiel.com';
  final password = 'mperez'; // Adjust if known

  try {
    print('Intentando login standard Auth ($email)...');
    final response = await client.auth.signInWithPassword(email: email, password: password);
    final user = response.user;
    if (user != null) {
      print('Login SUCCESS. User ID: ${user.id}');
      print('Intentando leer perfil AHORA QUE ESTAMOS AUTENTICADOS...');
      final profile = await client.from('profiles').select().eq('id', user.id).maybeSingle();
      print('PROFILE DATA: $profile');
    }
  } catch (e) {
    print('FAILED: $e');
  }
}
