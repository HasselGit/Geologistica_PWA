import 'package:supabase_flutter/supabase_flutter.dart';
import '../lib/backend/supabase_service.dart';

void main() async {
  // Inicializamos Supabase como lo hace main.dart
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('=== PROBANDO SUPABASESERVICE().GETCARGAS() ===');
  try {
    final service = SupabaseService();
    final cargas = await service.getCargas();
    print('getCargas() retornó ${cargas.length} cargas.');
    for (var c in cargas) {
      print('Carga: ID=${c['id']}, Código=${c['carga_codigo']}, Estado=${c['estado']}');
      print('  carga_items: ${c['carga_items']}');
      print('  Tipo de carga_items: ${c['carga_items']?.runtimeType}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
