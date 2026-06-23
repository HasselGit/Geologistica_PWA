import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('=== SIMULATING LOAD AUTO-GENERATION ===');
  try {
    // 1. Fetch the trip V-2105-906
    final tripList = await client.from('viajes').select('*').eq('viaje_codigo', 'V-2105-906');
    if (tripList.isEmpty) {
      print('Trip V-2105-906 not found!');
      return;
    }
    final trip = tripList.first;
    final tripId = trip['id'];

    // 2. Fetch the paradas and their associated solicitudes
    final paradas = await client.from('paradas').select('*').eq('viaje_id', tripId);
    print('Found ${paradas.length} paradas for trip V-2105-906');

    final List<Map<String, dynamic>> necesidades = [];
    for (var p in paradas) {
      if (p['solicitud_id'] != null) {
        final sol = await client.from('solicitudes').select('*').eq('id', p['solicitud_id']).maybeSingle();
        if (sol != null) {
          necesidades.add(sol);
        }
      }
    }

    print('\nSimulating with necesidades count: ${necesidades.length}');
    for (var n in necesidades) {
      print('  Need: ID=${n['id']}, Tipo=${n['tipo']}, Producto=${n['producto']}, Cantidad=${n['cantidad']}');
    }

    // 3. Replicate the auto-generation filter
    final dists = necesidades.where((n) {
      final tipo = (n['tipo'] ?? '').toString().toLowerCase();
      final matched = tipo.contains('dist');
      print('  Checking matching type for "${n['tipo']}": contains "dist"? $matched');
      return matched;
    }).toList();

    print('\nFound ${dists.length} distributions in necesidades');

    if (dists.isNotEmpty) {
      final Map<String, double> grouped = {};
      for (final n in dists) {
        final prod = (n['producto'] ?? '').toString();
        if (prod.isNotEmpty) {
          final double qty = (n['cantidad'] as num?)?.toDouble() ?? 0.0;
          grouped[prod] = (grouped[prod] ?? 0.0) + qty;
        }
      }
      print('Grouped items: $grouped');

      if (grouped.isNotEmpty) {
        final List<Map<String, dynamic>> itemsToLoad = grouped.entries.map((e) {
          final lowerProd = e.key.toLowerCase();
          final esUnidades = lowerProd.contains('tambor') ||
              lowerProd.contains('insumo') ||
              lowerProd.contains('alimento') ||
              lowerProd.contains('tcm') ||
              lowerProd.contains('tv');
          return {
            'producto_codigo': e.key,
            'cantidad': e.value,
            'unidad': esUnidades ? 'UN' : 'KG',
          };
        }).toList();

        print('Items to insert: $itemsToLoad');

        // Let's attempt to insert it into a dummy check
        final creatorId = 'd0744e5c-3d9c-4e17-be9e-90e55f4a4c61';
        print('Simulating createCarga execution...');
        
        final testCargaResp = await client.from('cargas').insert({
          'carga_codigo': 'TEST-SIM-${DateTime.now().millisecondsSinceEpoch}',
          'viaje_id': tripId,
          'estado': 'Pendiente',
          'created_by': creatorId,
        }).select('id').single();
        final testCargaId = testCargaResp['id'] as String;
        print('Temporary Carga created: $testCargaId');

        try {
          final itemsToInsert = itemsToLoad.map((item) => {
            'carga_id': testCargaId,
            'producto_codigo': item['producto_codigo'],
            'cantidad': (item['cantidad'] as num).toInt(),
            'unidad': item['unidad'] ?? 'UN',
          }).toList();
          print('Inserting items into carga_items: $itemsToInsert');
          await client.from('carga_items').insert(itemsToInsert);
          print('Successfully inserted items!');
        } catch (e) {
          print('Error inserting items into carga_items: $e');
        } finally {
          // Cleanup
          print('Cleaning up simulated load...');
          await client.from('carga_items').delete().eq('carga_id', testCargaId);
          await client.from('cargas').delete().eq('id', testCargaId);
          print('Cleanup done.');
        }
      }
    }
  } catch (e) {
    print('Simulation Error: $e');
  }
}
