import 'package:supabase/supabase.dart';
import 'dart:io';
void main() async {
  final url = File('.env').readAsStringSync().split('\n').firstWhere((l) => l.startsWith('SUPABASE_URL')).split('=')[1].trim();
  final key = File('.env').readAsStringSync().split('\n').firstWhere((l) => l.startsWith('SUPABASE_ANON_KEY')).split('=')[1].trim();
  final c = SupabaseClient(url, key);
  final d = await c.from('pesajes').select().limit(5);
  print(d);
}
