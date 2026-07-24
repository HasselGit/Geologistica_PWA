import 'package:supabase/supabase.dart';
import 'dart:io';

void main() async {
  final supabaseUrl = 'https://suwcqdlxnmfcvmlnzizl.supabase.co';
  final supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o';
  
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  
  try {
    final pData = await client.from('paradas')
        .select('id, created_at, tipo, estado, solicitud_id, parada_items(producto_codigo, cantidad, unidad, apicultor_titular, apicultor_id), remitos(numero_remito, pdf_url, apicultor_id)')
        .limit(1);
    print("Success: \$pData");
  } catch (e) {
    print("Error in paradas query: \$e");
  }
  
  exit(0);
}
