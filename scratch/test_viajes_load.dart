import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient('https://suwcqdlxnmfcvmlnzizl.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o');
  
  final String? userId = 'e848a79c-5928-4890-aec4-80129189729d';
  final String? role = 'CEO';

  var query = client.from('viajes').select('*');

  if (role == 'Chofer' && userId != null) {
    query = query.eq('chofer_id', userId);
  }

  final res = await query.order('created_at', ascending: false);
  
  print('VIAJES ENCONTRADOS PARA MARIANO:');
  print('Total: ${res.length}');
  for (var v in res) {
    print('- ID: ${v['id']} | Cod: ${v['viaje_codigo']} | Estado: ${v['estado']}');
  }
}
