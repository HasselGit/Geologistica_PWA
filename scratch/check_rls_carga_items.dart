import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== CHECKING RLS POLICIES FOR CARGA_ITEMS WITH MAIN.DART ANON KEY ===');
  try {
    final res = await client.from('carga_items').select('*');
    print('Direct select from carga_items succeeded: found ${res.length} rows.');
    for (var item in res) {
      print('  Item ID: ${item['id']}, Carga ID: ${item['carga_id']}, Prod: ${item['producto_codigo']}, Qty: ${item['cantidad']}');
    }
  } catch (e) {
    print('Direct select failed: $e');
  }

  print('\n=== CHECKING CARGAS DIRECT QUERY ===');
  try {
    final res = await client.from('cargas').select('*, carga_items(*)');
    print('Query cargas with carga_items succeeded: found ${res.length} cargas.');
    for (var load in res) {
      print('  Load Code: ${load['carga_codigo']}');
      print('  Load ID: ${load['id']}');
      print('  Items: ${load['carga_items']}');
    }
  } catch (e) {
    print('Query cargas with carga_items failed: $e');
  }
}
