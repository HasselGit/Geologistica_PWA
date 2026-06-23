import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== DIAGNOSING DATABASE TRIGGERS VIA SQL ===');
  
  final sql = '''
    SELECT 
        trg.tgname AS trigger_name,
        tbl.relname AS table_name,
        trg.tgtype AS trigger_type,
        proc.proname AS function_name,
        pg_get_triggerdef(trg.oid) AS trigger_definition
    FROM pg_trigger trg
    JOIN pg_class tbl ON trg.tgrelid = tbl.oid
    JOIN pg_namespace ns ON tbl.relnamespace = ns.oid
    JOIN pg_proc proc ON trg.tgfoid = proc.oid
    WHERE ns.nspname = 'public'
      AND tbl.relname IN ('paradas', 'remitos', 'solicitudes')
      AND NOT trg.tgisinternal;
  ''';

  try {
    final res = await client.rpc('exec_sql', params: {'sql': sql});
    print('✅ PostgreSQL Triggers Found:');
    if (res is List) {
      for (var row in res) {
        print('--------------------------------------------------');
        print('Trigger: ${row['trigger_name']} on table: ${row['table_name']}');
        print('Function: ${row['function_name']}');
        print('Definition: ${row['trigger_definition']}');
      }
    } else {
      print('Response: $res');
    }
  } catch (e) {
    print('❌ Error fetching pg_triggers: $e');
  }
}
