import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  try {
    print('Intentando ejecutar SQL vía RPC exec_sql...');
    final res = await client.rpc('exec_sql', params: {
      'sql': 'ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rol TEXT; UPDATE profiles SET rol = puesto WHERE rol IS NULL;'
    });
    print('Resultado: $res');
  } catch (e) {
    print('Error RPC: $e');
  }
}
