import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final res = await client.from('solicitudes').select().or('apicultor_id.eq.A01508,apicultor_id.eq.1508');
  print('FENOGLIO SOLICITUDES (ALL IDS): ${res.length}');
  for (var r in res) {
    print('ID: ${r['id']} | Cod: ${r['solicitud_codigo']} | Estado: ${r['estado']} | ApiID: ${r['apicultor_id']}');
  }
}
