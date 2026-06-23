import 'package:supabase/supabase.dart';

void main() async {
  print('--- CHECKING SUPABASE SCHEMA ---');
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('\nChecking apicultores table...');
    final apiData = await client.from('apicultores').select().limit(1);
    if (apiData is List && apiData.isNotEmpty) {
      print('Apicultores column keys: ${apiData[0].keys.toList()}');
    } else {
      print('Apicultores table is empty.');
    }
  } catch (e) {
    print('Error checking apicultores: $e');
  }

  try {
    print('\nChecking productos table...');
    final prodData = await client.from('productos').select().limit(1);
    if (prodData is List && prodData.isNotEmpty) {
      print('Productos column keys: ${prodData[0].keys.toList()}');
    } else {
      print('Productos table is empty.');
    }
  } catch (e) {
    print('Error checking productos: $e');
  }
}
