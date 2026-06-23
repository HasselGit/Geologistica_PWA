import 'package:supabase/supabase.dart';

void main() async {
  print('--- POBLANDO INVENTARIO DE PRODUCTOS (MODO RESILIENTE) ---');
  
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final products = [
    {'codigo': '1', 'acro': 'TCM', 'desc': 'Tambor con Miel', 'uni': 'Uni'},
    {'codigo': '2', 'acro': 'TRR', 'desc': 'Tambor Reacondicionado Raldas', 'uni': 'Uni'},
    {'codigo': '3', 'acro': 'TRC', 'desc': 'Tambor Reacondicionado Cosde', 'uni': 'Uni'},
    {'codigo': '4', 'acro': 'TRO', 'desc': 'Tambor Reacondicionado Ombu', 'uni': 'Uni'},
    {'codigo': '5', 'acro': 'TNAR', 'desc': 'Tambor Nuevo Alto Raldas', 'uni': 'Uni'},
    {'codigo': '6', 'acro': 'TNAF', 'desc': 'Tambor Nuevo Alto Fabritam', 'uni': 'Uni'},
    {'codigo': '7', 'acro': 'TNP', 'desc': 'Tambor Nuevo Petiso', 'uni': 'Uni'},
    {'codigo': '8', 'acro': 'CO', 'desc': 'Cera Operculo', 'uni': 'Kg'},
    {'codigo': '9', 'acro': 'CR', 'desc': 'Cera Recupero', 'uni': 'Kg'},
    {'codigo': '10', 'acro': 'CE STD', 'desc': 'Cera Estampada STD', 'uni': 'Uni'},
    {'codigo': '11', 'acro': 'CE 3/4', 'desc': 'Cera Estampada 3/4', 'uni': 'Uni'},
    {'codigo': '13', 'acro': 'TE', 'desc': 'Techo Calden', 'uni': 'Uni'},
    {'codigo': '14', 'acro': 'PI', 'desc': 'Piso Calden', 'uni': 'Uni'},
    {'codigo': '15', 'acro': 'AL1 STD', 'desc': 'Alzas de Primera STD', 'uni': 'Uni'},
    {'codigo': '16', 'acro': 'AL2 STD', 'desc': 'Alzas de Segunda STD', 'uni': 'Uni'},
    {'codigo': '19', 'acro': 'TV', 'desc': 'Tabla de Varroa', 'uni': 'Caja x 600 Uni'},
    {'codigo': '20', 'acro': 'AZ', 'desc': 'Azucar', 'uni': 'Bolsa x 50 Kg'},
    {'codigo': '21', 'acro': 'GL', 'desc': 'Glucosa', 'uni': 'Kg'},
    {'codigo': '22', 'acro': 'TRM S/B', 'desc': 'Tambor Reacondicionado Myhura S/B', 'uni': 'Uni'},
    {'codigo': '23', 'acro': 'TRM C/B', 'desc': 'Tambor Reacondicionado Myhura C/B', 'uni': 'Uni'},
    {'codigo': '17', 'acro': 'AL1 3/4', 'desc': 'Alzas de Primera 3/4', 'uni': 'Uni'},
    {'codigo': '18', 'acro': 'AL2 3/4', 'desc': 'Alzas de Segunda 3/4', 'uni': 'Uni'},
    {'codigo': '24', 'acro': 'LA', 'desc': 'Largueros', 'uni': 'Uni'},
    {'codigo': '12', 'acro': 'NU', 'desc': 'Nucleros', 'uni': 'Uni'},
    {'codigo': '25', 'acro': 'CU', 'desc': 'Cuadros', 'uni': 'Uni'},
  ];

  try {
    print('Insertando ${products.length} productos...');
    for (var p in products) {
      final row = {
        'codigo': p['codigo'],
        'descripcion': '${p['desc']} (${p['acro']})', // Fallback: acronym in description
        'unidad': p['uni'],
      };
      
      // Intentamos con 'nombre' si es que existe
      try {
        await client.from('productos').insert({
          ...row,
          'nombre': p['acro'],
          'descripcion': p['desc'],
        });
        print('Insertado (con nombre): ${p['acro']}');
      } catch (e) {
        // Fallback sin 'nombre'
        await client.from('productos').insert(row);
        print('Insertado (fallback): ${p['acro']}');
      }
    }
    
    print('--- PROCESO COMPLETADO ---');
  } catch (e) {
    print('Error crítico: $e');
  }
}
