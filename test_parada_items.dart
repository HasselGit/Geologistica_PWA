import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- TEST PARADA_ITEMS ---');
  try {
    final res = await client.from('parada_items').select('*').order('created_at', ascending: false).limit(5);
    print('✅ Parada_items OK! Encontradas: ${List.from(res).length}');
    for (var item in List.from(res)) {
      print(item);
    }
  } catch (e) {
    print('❌ Error Parada_items: $e');
  }

  print('--- TEST PESAJES ---');
  try {
    final res = await client.from('pesajes').select('*').order('created_at', ascending: false).limit(5);
    print('✅ Pesajes OK! Encontrados: ${List.from(res).length}');
    for (var item in List.from(res)) {
      print(item);
    }
  } catch (e) {
    print('❌ Error Pesajes: $e');
  }
}
