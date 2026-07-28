import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabaseUrl = 'https://suwcqdlxnmfcvmlnzizl.supabase.co';
  final supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o';
  final client = SupabaseClient(supabaseUrl, supabaseKey);

  try {
    final pesajesData = await client.from('pesajes')
        .select('*, paradas(id, tipo, estado, viaje_id, viajes(codigo_viaje))')
        .eq('apicultor_id', 'A02712')
        .order('created_at', ascending: false)
        .limit(500);
    print('SUCCESS: \ pesajes');
  } catch (e) {
    print('ERROR: e');
  }
  exit(0);
}
