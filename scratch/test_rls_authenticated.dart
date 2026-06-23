import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  await testUser(client, 'mperez@geomiel.com', 'mperez');
  print('========================================');
  await testUser(client, 'hassel00@gmail.com', 'hassel00');
}

Future<void> testUser(SupabaseClient client, String email, String password) async {
  try {
    print('Signing in as $email...');
    final authRes = await client.auth.signInWithPassword(email: email, password: password);
    final user = authRes.user;
    if (user == null) {
      print('Failed to sign in.');
      return;
    }
    print('Sign in successful. User ID: ${user.id}');

    print('Querying carga_items directly as authenticated user...');
    try {
      final items = await client.from('carga_items').select('*');
      print('Found ${items.length} items in carga_items directly.');
      for (var item in items) {
        print('  Item: ${item['producto_codigo']} x ${item['cantidad']}');
      }
    } catch (e) {
      print('Query to carga_items failed: $e');
    }

    print('Querying cargas with carga_items join as authenticated user...');
    try {
      final loads = await client.from('cargas').select('*, carga_items(*)');
      print('Found ${loads.length} cargas.');
      for (var load in loads) {
        print('  Load Code: ${load['carga_codigo']}');
        print('  Items: ${load['carga_items']}');
      }
    } catch (e) {
      print('Query to cargas with join failed: $e');
    }

    print('Signing out...');
    await client.auth.signOut();
  } catch (e) {
    print('Error testing user $email: $e');
  }
}
