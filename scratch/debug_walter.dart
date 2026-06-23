import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o'
  );

  print('--- Debugging Walter Spinozzi ---');
  
  final apicultores = await supabase.from('apicultores').select().ilike('nombre', '%Walter%');
  print('Apicultores matches: $apicultores');

  if (apicultores.isNotEmpty) {
    final walter = apicultores.first;
    final apiId = walter['apicultor_codigo'] ?? walter['id'];
    print('Searching for solicitudes with apicultor_id = $apiId');
    
    final sols = await supabase.from('solicitudes').select().eq('apicultor_id', apiId);
    print('Solicitudes matches: ${sols.length}');
    for (var s in sols) {
      print('  - ${s['id']} | ${s['producto']} | ${s['estado']}');
    }
    
    // Check if there are sols with the other ID format
    String altId = apiId.toString();
    if (altId.startsWith('A')) {
      altId = altId.replaceAll(RegExp(r'^A0*'), '');
    } else {
      altId = 'A${altId.padLeft(5, '0')}';
    }
    print('Searching for solicitudes with alternate ID = $altId');
    final altSols = await supabase.from('solicitudes').select().eq('apicultor_id', altId);
    print('Alternate Solicitudes matches: ${altSols.length}');
  }
}
