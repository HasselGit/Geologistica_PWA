import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final apiId = 'A01887';
  List<String> idCandidates = [apiId, '1887'];
  String orFilter = idCandidates.map((id) => 'apicultor_id.eq.$id').join(',');

  final allSolsRes = await client.from('solicitudes')
      .select('*')
      .or(orFilter)
      .order('created_at', ascending: false);
  
  print('RESULTS for $apiId: ${allSolsRes.length}');
  for (var s in allSolsRes) {
    print('ID: ${s['id']} | Cod: ${s['solicitud_codigo']} | Estado: ${s['estado']} | Apicultor: ${s['apicultor_id']}');
  }
}
