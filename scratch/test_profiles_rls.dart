import 'package:supabase/supabase.dart';

void main() async {
  // Usando la EXACTA URL y KEY del main.dart
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Probando lectura de profiles con ANON_KEY ---');
  try {
    final response = await client.from('profiles').select().limit(1);
    print('Lectura exitosa: $response');
  } catch (e) {
    print('Error de lectura (posible RLS): $e');
  }
}
