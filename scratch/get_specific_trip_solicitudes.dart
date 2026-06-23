import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final res = await client.from('solicitudes').select().or('id.eq.7b0fb6cd-7e20-48a5-bcd8-c775e8278b6b,id.eq.767e6fa6-13ae-4f1d-96bc-4698c3474f3e');
  for (var s in res) {
    print('ID: ${s['id']} | Apicultor: ${s['apicultor_id']} | Cod: ${s['solicitud_codigo']} | Estado: ${s['estado']}');
  }
}
