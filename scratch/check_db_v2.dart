import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Viajes count:');
    final v = await client.from('viajes').select('id').limit(1);
    print('Viajes data: $v');
    
    print('\nChecking profiles again without select filter...');
    final p = await client.from('profiles').select();
    print('Profiles data: $p');
    
    print('\nChecking if there are other tables related to users...');
    // Maybe 'usuarios'?
    try {
      final u = await client.from('usuarios').select().limit(1);
      print('Usuarios data: $u');
    } catch (_) {}

  } catch (e) {
    print('Error: $e');
  }
}
