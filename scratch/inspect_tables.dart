import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final supabase = SupabaseClient('https://vstvyqclwpxubqivxozb.supabase.co', 'YOUR_KEY_FROM_CODE');
  
  print('--- SOLICITUDES ---');
  try {
    final sol = await supabase.from('solicitudes').select('*').limit(1);
    print(sol);
  } catch (e) { print(e); }

  print('--- NECESIDADES ---');
  try {
    final nec = await supabase.from('necesidades').select('*').limit(1);
    print(nec);
  } catch (e) { print(e); }
}
