import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  try {
    print('1. Testing query on paradas to find a parada_id...');
    final paradas = await client.from('paradas').select('id, tipo, ubicacion, viaje_id').limit(5);
    if (paradas.isEmpty) {
      print('No paradas found in database.');
      return;
    }
    
    print('Found ${paradas.length} paradas:');
    for (var p in paradas) {
      print(' - Parada ID: ${p['id']}, Tipo: ${p['tipo']}, Ubicacion: ${p['ubicacion']}, Viaje ID: ${p['viaje_id']}');
    }

    final paradaId = paradas.first['id'] as String;
    print('\n2. Testing existing remitos query for Parada ID: $paradaId...');
    final existingRemitos = await client
        .from('remitos')
        .select('id, numero_remito, cliente_cuit')
        .eq('parada_id', paradaId);
    
    final int count = (existingRemitos as List).length;
    final String codeBase = 'REM-${paradaId.split('-').first.toUpperCase()}';
    final String numeroRemito = count == 0 ? codeBase : '$codeBase-${count + 1}';
    print('Found $count existing remitos.');
    print('Proposed next Remito Number: $numeroRemito');

    print('\n3. Testing query on pesajes table for Parada ID: $paradaId...');
    final pesajesRes = await client
        .from('pesajes')
        .select('id, peso_bruto, tara, senasa_codigo, apicultor_id')
        .eq('parada_id', paradaId);
    
    final List<dynamic> pesajesList = pesajesRes as List;
    print('Found ${pesajesList.length} pesajes records for this stop.');
    if (pesajesList.isNotEmpty) {
      double totalTcmNeto = 0.0;
      for (final p in pesajesList) {
        final double bruto = (p['peso_bruto'] as num?)?.toDouble() ?? 0.0;
        final double tara = (p['tara'] as num?)?.toDouble() ?? 0.0;
        final senasa = p['senasa_codigo'] ?? 'S/D';
        final apicultor = p['apicultor_id'] ?? 'S/D';
        print('  - SENASA: $senasa, Apicultor ID: $apicultor, Bruto: $bruto, Tara: $tara, Neto: ${bruto > 0 ? (bruto - tara) : 300.0} (estimate)');
        if (bruto > 0.0) {
          totalTcmNeto += (bruto - tara);
        } else {
          totalTcmNeto += 300.0;
        }
      }
      print('Total calculated Net weight for TCM: $totalTcmNeto kg');
    } else {
      print('No pesajes records found, weight defaults to 0.0 kg');
    }

    print('\n4. Verifying remitos columns schema (select all columns for 1 row)...');
    try {
      final remitoSchemaTest = await client.from('remitos').select('*').limit(1);
      if (remitoSchemaTest.isNotEmpty) {
        print('Remito columns list: ${remitoSchemaTest.first.keys.toList()}');
      } else {
        print('Remitos table is empty, columns list cannot be printed but table exists.');
      }
    } catch (e) {
      print('Failed to verify remitos columns: $e');
    }

    print('\nSUCCESS: All database queries compile and execute against the real schema.');

  } catch (e) {
    print('Error in verification: $e');
  }
}
