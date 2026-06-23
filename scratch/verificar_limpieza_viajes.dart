import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('--- Verificando viajes en Supabase ---');
  
  // Usamos las credenciales que ya están configuradas en el proyecto
  // (Esto es solo para diagnóstico rápido)
  final supabase = SupabaseClient(
    'https://pwnpujitidshfxtatpao.supabase.co', 
    'eyJh...', // Se usará la del sistema
  );

  try {
    final res = await Supabase.instance.client.from('viajes').select('id, viaje_codigo, estado, created_at');
    print('Total de viajes encontrados: ${res.length}');
    for (var v in res) {
      print('Viaje: ${v['viaje_codigo']} | Estado: ${v['estado']} | Creado: ${v['created_at']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
