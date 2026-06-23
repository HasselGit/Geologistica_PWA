
import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  print('--- TEST LOGIN BYPASS START ---');
  final supabase = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final email = 'mparedes@geomiel.com';
  final password = 'mparedes';

  print('Querying database directly for: $email');
  try {
    final response = await supabase
        .from('profiles')
        .select()
        .eq('email', email)
        .eq('contrasena', password)
        .maybeSingle();

    if (response != null) {
      print('SUCCESS! User found: ${response['nombre']} ${response['apellido']}');
      print('User ID: ${response['id']}');
      print('Role: ${response['puesto']}');
    } else {
      print('FAILURE: User not found with these credentials.');
    }
  } catch (e) {
    print('ERROR during query: $e');
  }
  print('--- TEST LOGIN BYPASS END ---');
  exit(0);
}
