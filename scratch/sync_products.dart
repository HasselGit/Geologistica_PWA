import 'package:supabase/supabase.dart';

void main() async {
  print('=== SINCRONIZANDO PRODUCTOS CON EL COMPORTAMIENTO MAESTRO DE EXCEL ===');

  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  // Lista maestra de 25 productos correctos
  final List<Map<String, dynamic>> masterProductsList = [
    {'codigo': 'TCM', 'descripcion': 'Tambor con Miel', 'unidad': 'Uni'},
    {'codigo': 'TRR', 'descripcion': 'Tambor Reacondicionado Raldas', 'unidad': 'Uni'},
    {'codigo': 'TRC', 'descripcion': 'Tambor Reacondicionado Cosde', 'unidad': 'Uni'},
    {'codigo': 'TRO', 'descripcion': 'Tambor Reacondicionado Ombu', 'unidad': 'Uni'},
    {'codigo': 'TNAR', 'descripcion': 'Tambor Nuevo Alto Raldas', 'unidad': 'Uni'},
    {'codigo': 'TNAF', 'descripcion': 'Tambor Nuevo Alto Fabritam', 'unidad': 'Uni'},
    {'codigo': 'TNP', 'descripcion': 'Tambor Nuevo Petiso', 'unidad': 'Uni'},
    {'codigo': 'CO', 'descripcion': 'Cera Operculo', 'unidad': 'Kg'},
    {'codigo': 'CR', 'descripcion': 'Cera Recupero', 'unidad': 'Kg'},
    {'codigo': 'CE STD', 'descripcion': 'Cera Estampada STD', 'unidad': 'Uni'},
    {'codigo': 'CE 3/4', 'descripcion': 'Cera Estampada 3/4', 'unidad': 'Uni'},
    {'codigo': 'TE', 'descripcion': 'Techo Calden', 'unidad': 'Uni'},
    {'codigo': 'PI', 'descripcion': 'Piso Calden', 'unidad': 'Uni'},
    {'codigo': 'AL1 STD', 'descripcion': 'Alzas de Primera STD', 'unidad': 'Uni'},
    {'codigo': 'AL2 STD', 'descripcion': 'Alzas de Segunda STD', 'unidad': 'Uni'},
    {'codigo': 'TV', 'descripcion': 'Tabla de Varroa', 'unidad': 'Caja x 600 Uni'},
    {'codigo': 'AZ', 'descripcion': 'Azucar', 'unidad': 'Bolsa x 50 Kg'},
    {'codigo': 'GL', 'descripcion': 'Glucosa', 'unidad': 'Kg'},
    {'codigo': 'TRM S/B', 'descripcion': 'Tambor Reacondicionado Myhura S/B', 'unidad': 'Uni'},
    {'codigo': 'TRM C/B', 'descripcion': 'Tambor Reacondicionado Myhura C/B', 'unidad': 'Uni'},
    {'codigo': 'AL1 3/4', 'descripcion': 'Alzas de Primera 3/4', 'unidad': 'Uni'},
    {'codigo': 'AL2 3/4', 'descripcion': 'Alzas de Segunda 3/4', 'unidad': 'Uni'},
    {'codigo': 'LA', 'descripcion': 'Largueros', 'unidad': 'Uni'},
    {'codigo': 'NU', 'descripcion': 'Nucleros', 'unidad': 'Uni'},
    {'codigo': 'CU', 'descripcion': 'Cuadros', 'unidad': 'Uni'},
  ];

  try {
    print('1. Eliminando filas temporales con códigos numéricos de prueba...');
    final numericCodes = List.generate(26, (index) => index.toString());
    try {
      await client.from('productos').delete().filter('codigo', 'in', numericCodes);
      print('Filas de prueba eliminadas.');
    } catch (e) {
      print('Advertencia al eliminar filas de prueba: $e');
    }

    print('2. Eliminando código duplicado/antiguo de Azúcar (si existe)...');
    try {
      await client.from('productos').delete().eq('codigo', 'Azúcar');
      print('Duplicado antiguo "Azúcar" eliminado.');
    } catch (e) {
      print('Advertencia al eliminar duplicado de Azúcar: $e');
    }

    print('3. Sincronizando catálogo maestro con la base de datos (mediante Upsert)...');
    for (var p in masterProductsList) {
      try {
        // Buscamos si existe para actualizar, o si no insertamos
        final existing = await client.from('productos').select().eq('codigo', p['codigo']).maybeSingle();
        if (existing != null) {
          await client.from('productos').update({
            'descripcion': p['descripcion'],
            'unidad': p['unidad'],
            'activo': true,
          }).eq('codigo', p['codigo']);
          print('Actualizado en DB: ${p['codigo']} -> ${p['descripcion']} (${p['unidad']})');
        } else {
          await client.from('productos').insert({
            'codigo': p['codigo'],
            'descripcion': p['descripcion'],
            'unidad': p['unidad'],
            'activo': true,
          });
          print('Insertado en DB: ${p['codigo']} -> ${p['descripcion']} (${p['unidad']})');
        }
      } catch (err) {
        print('Error procesando ${p['codigo']}: $err');
      }
    }

    print('\n=== PROCESO DE SINCRONIZACIÓN FINALIZADO CON ÉXITO ===');
  } catch (e) {
    print('Error crítico en sync_products: $e');
  }
}
