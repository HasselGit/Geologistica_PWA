import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );
  try {
    print('Intentando ejecutar SQL para agregar columna tipo_operacion a parada_items...');
    final res = await client.rpc('exec_sql', params: {
      'sql': "ALTER TABLE parada_items ADD COLUMN IF NOT EXISTS tipo_operacion TEXT DEFAULT 'Recolección';"
    });
    print('Resultado de la migracion: $res');
  } catch (e) {
    print('Error RPC: $e');
  }
}
