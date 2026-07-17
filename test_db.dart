import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY')
  );
  final res = await Supabase.instance.client.from('vehiculos').select('*');
  print(res);
  exit(0);
}
