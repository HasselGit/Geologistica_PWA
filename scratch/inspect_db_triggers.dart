import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== DIAGNOSING DATABASE TRIGGERS ===');
  
  // Try querying pg_trigger or database objects via direct SQL if possible
  try {
    final res = await client.rpc('get_triggers_info');
    print('✅ Trigger RPC response: $res');
  } catch (e) {
    print('ℹ️ RPC "get_triggers_info" not found or failed: $e');
  }

  // Let's inspect the behavior of inserting a remito or updating a solicitud to see if paradas change state automatically.
  // We can query database structure using public tables if exposed.
  try {
    final res = await client.from('solicitudes').select('id, estado').limit(1);
    print('✅ Solicitudes schema accessible: $res');
  } catch (e) {
    print('❌ Solicitudes access error: $e');
  }
}
