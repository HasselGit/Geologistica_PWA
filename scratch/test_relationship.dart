import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final attempts = [
    '*, profiles!viajes_chofer_id_fkey(nombre, apellido)',
    '*, profiles!chofer_id(nombre, apellido)',
    '*, profiles:chofer_id(nombre, apellido)',
    '*, profiles(nombre, apellido)',
  ];

  for (var select in attempts) {
    try {
      print('Trying: $select');
      final res = await client.from('viajes').select(select).limit(1);
      print('SUCCESS! Result: $res');
      break;
    } catch (e) {
      print('FAILED: $e');
    }
  }
}
