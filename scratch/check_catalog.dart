import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  final client = Supabase.instance.client;
  
  print('--- Verificando Catálogo ---');
  try {
    final res = await client.from('catalogo_productos').select().limit(5);
    print('[OK] catalogo_productos existe: $res');
  } catch (e) {
    print('[ERROR] catalogo_productos NO existe: $e');
  }
}
