import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('Intentando iniciar sesion con mparedes@geomiel.com...');
  try {
    final authRes = await supabase.auth.signInWithPassword(
      email: 'mparedes@geomiel.com',
      password: 'mparedes',
    );
    print('Auth Result: ' + authRes.user!.email.toString());
    
    if (authRes.user != null) {
      final profile = await supabase.from('profiles')
          .select()
          .eq('id', authRes.user!.id)
          .maybeSingle();
      print('Perfil: ' + profile.toString());
    }
  } catch (e) {
    print('Error REAL: ' + e.toString());
  }
}
