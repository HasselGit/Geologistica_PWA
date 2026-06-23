import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('Probing tables by calling .select().limit(0) on common logistics names...');
    final potential = [
      'profiles', 'users', 'usuarios', 
      'viajes', 'paradas', 'parada_items', 'remitos', 'pesajes', 
      'vehiculos', 'apicultores', 'necesidades', 'inventario', 'tambores'
    ];
    
    for (final t in potential) {
      try {
        await client.from(t).select().limit(0);
        print('EXISTS: $t');
      } catch (e) {
        if (e.toString().contains('42P01')) {
          // Relation does not exist
        } else {
          print('EXISTS (with error): $t - $e');
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
