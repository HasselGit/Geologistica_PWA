import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final possibleCols = [
    'id', 'parada_id', 'chofer_id', 'apicultor_id', 'viaje_id', 
    'remito_codigo', 'firma_url', 'pdf_url', 'estado', 'fecha', 
    'persona_nombre', 'persona_dni', 'created_at', 'tipo_operacion', 'tipo'
  ];
  print('--- Checking remitos columns ---');
  for (var col in possibleCols) {
    try {
      await client.from('remitos').select(col).limit(1);
      print('Column "$col" exists');
    } catch (e) {
      print('Column "$col" DOES NOT exist or failed: $e');
    }
  }
}
