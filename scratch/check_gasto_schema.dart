import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== CHECK GASTO SCHEMA ===');
  try {
    final sample = await client.from('gastos').select().limit(1);
    if (sample.isNotEmpty) {
      print('✅ Gastos sample row: ${sample.first}');
    } else {
      print('ℹ️ Gastos table is empty, trying to insert a dummy and roll back...');
      // We can insert a minimalist row to get the schema or list the columns if they throw error
      try {
        final dummy = await client.from('gastos').insert({
          'tipo_gasto': 'Otros',
          'importe': 0,
        }).select().single();
        print('✅ Inserted dummy row: $dummy');
        await client.from('gastos').delete().eq('id', dummy['id']);
      } catch (insertErr) {
        print('❌ Insert dummy error: $insertErr');
      }
    }
  } catch (e) {
    print('❌ Failed to select from gastos: $e');
  }
}
