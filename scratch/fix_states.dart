import 'package:supabase/supabase.dart';

// Definición mínima de estados para no depender de otros archivos en el script
class States {
  static const String pendiente  = 'Pendiente';
  static const String asignada   = 'Asignada';
  static const String enCurso    = 'En Curso';
  static const String terminado  = 'Terminado';

  static String normalize(dynamic val) {
    final clean = val?.toString().toLowerCase().trim() ?? '';
    if (clean == 'pendiente' || clean == 'solicitado' || clean == 'planificado' || clean == 'planificada' || clean == 'cargado') return pendiente;
    if (clean == 'en proceso' || clean == 'en curso' || clean == 'enproceso' || clean == 'encurso') return enCurso;
    if (clean.contains('terminado') || clean.contains('finalizado')) return terminado;
    if (clean.contains('asignada')) return asignada;
    return pendiente;
  }
}

void main() async {
  print('Iniciando limpieza profunda de estados (CORREGIDO)...');
  
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    // 1. Corregir Viajes con estado 'Cargado' -> 'Pendiente'
    final List<dynamic> cargados = await client.from('viajes').select('id, viaje_codigo, estado').eq('estado', 'Cargado');
    if (cargados.isNotEmpty) {
      print('Corrigiendo ${cargados.length} viajes con estado erróneo "Cargado"...');
      for (var v in cargados) {
        await client.from('viajes').update({'estado': States.pendiente}).eq('id', v['id']);
        print('  - Viaje ${v['viaje_codigo']} movido a Pendiente');
      }
    }

    // 2. Obtener todas las solicitudes no terminadas
    final List<dynamic> sols = await client.from('solicitudes')
        .select('id, estado, apicultor_id, producto, tipo')
        .not('estado', 'ilike', 'terminad%');
    
    print('Analizando ${sols.length} solicitudes activas...');
    
    int fixedCount = 0;
    
    for (var s in sols) {
      final solId = s['id'].toString();
      final currentEstado = s['estado']?.toString() ?? 'Pendiente';
      
      // Buscar vinculación a viaje SOLO vía parada (visto en auditoría que parada_items NO tiene solicitud_id)
      final List<dynamic> paradas = await client.from('paradas')
          .select('id, viaje_id, viajes(estado)')
          .eq('solicitud_id', solId);
          
      Map<String, dynamic>? linkedViaje;
      if (paradas.isNotEmpty && paradas.first['viajes'] != null) {
        linkedViaje = paradas.first['viajes'];
      }
      
      if (linkedViaje == null) {
        // No está en un viaje -> Pendiente
        if (currentEstado != States.pendiente && currentEstado != 'Solicitado') {
          print('FIX: Solicitud $solId (${s['tipo']} ${s['producto']}) -> Pendiente (estaba $currentEstado)');
          await client.from('solicitudes').update({'estado': States.pendiente}).eq('id', solId);
          fixedCount++;
        }
      } else {
        // Está en un viaje, ver el estado del viaje
        final vEstado = States.normalize(linkedViaje['estado']);
        String targetEstado;
        
        if (vEstado == States.enCurso) {
          targetEstado = States.enCurso;
        } else {
          // Si el viaje es Pendiente/Planificado/Cargado -> La solicitud es ASIGNADA
          targetEstado = States.asignada;
        }
        
        if (currentEstado != targetEstado) {
          print('FIX: Solicitud $solId (${s['tipo']} ${s['producto']}) -> $targetEstado (estaba $currentEstado, viaje era $vEstado)');
          await client.from('solicitudes').update({'estado': targetEstado}).eq('id', solId);
          fixedCount++;
        }
      }
    }
    
    print('\nProceso finalizado.');
    print('Viajes corregidos: ${cargados.length}');
    print('Solicitudes corregidas: $fixedCount');
  } catch (e, stack) {
    print('ERROR CRÍTICO: $e');
    print(stack);
  }
}
