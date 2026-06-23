import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Checking viajes table structure...');
    final data = await client.from('viajes').select().limit(1);
    if (data.isNotEmpty) {
      print('Viajes columns: ${data[0].keys.toList()}');
    } else {
      print('Viajes table is empty.');
    }

    print('\nChecking paradas table structure...');
    final paradas = await client.from('paradas').select().limit(1);
    if (paradas.isNotEmpty) {
      print('Paradas columns: ${paradas[0].keys.toList()}');
    } else {
      print('Paradas table is empty.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
