import 'package:supabase/supabase.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('--- SINCRONIZACIÓN APICULTORES (V7 - SEGURA) ---');

  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final gSheetId = '1vcg7nmkTfp_AyTTkTOGuGu7k-B2eAAUA_V8P24wa1Es';
  final gidApicultores = '1388406787';

  final apicultoresCsv = await _fetchCsv(gSheetId, gidApicultores);
  if (apicultoresCsv.isEmpty) return;

  // Detectar columnas reales en la DB para no fallar el upsert
  print('Verificando esquema en Supabase...');
  List<String> dbColumns = [];
  try {
    final sample = await client.from('apicultores').select().limit(1);
    if (sample.isNotEmpty) {
      dbColumns = sample[0].keys.toList();
    }
  } catch (e) {
    print('Error detectando columnas: $e');
    return;
  }
  print('Columnas detectadas en Supabase: $dbColumns');

  int successCount = 0;
  for (var i = 1; i < apicultoresCsv.length; i++) {
    final row = apicultoresCsv[i];
    if (row.length < 2) continue;
    
    String id = row[0].toString().trim();
    String nombre = row[1].toString().trim();
    if (nombre.isEmpty || id.isEmpty) continue;

    Map<String, dynamic> data = {
      'id': id,
      'nombre': nombre,
    };

    if (dbColumns.contains('localidad') && row.length > 2) data['localidad'] = row[2].trim();
    if (dbColumns.contains('provincia') && row.length > 3) data['provincia'] = row[3].trim();
    if (dbColumns.contains('cuit') && row.length > 5) data['cuit'] = row[5].trim();
    if (dbColumns.contains('telefono') && row.length > 7) data['telefono'] = row[7].trim();
    
    // Si existieran estas columnas las llenaríamos:
    if (dbColumns.contains('dni') && row.length > 4) data['dni'] = row[4].toString().split('.')[0].trim();
    if (dbColumns.contains('renapa') && row.length > 6) data['renapa'] = row[6].trim();

    try {
      await client.from('apicultores').upsert(data);
      successCount++;
      if (i % 25 == 0) print('  Procesados $i apicultores...');
    } catch (e) {
      print('  Error en $nombre ($id): $e');
    }
  }
  
  print('\n--- RESULTADOS ---');
  print('Total sincronizados: $successCount / ${apicultoresCsv.length - 1}');
  if (!dbColumns.contains('dni')) {
    print('AVISO: La columna "dni" NO existe en la tabla "apicultores".');
  }
  if (!dbColumns.contains('renapa')) {
    print('AVISO: La columna "renapa" NO existe en la tabla "apicultores".');
  }
}

Future<List<List<String>>> _fetchCsv(String id, String gid) async {
  final url = 'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=$gid';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) return [];
  return CsvToListConverter().convert(response.body);
}

class CsvToListConverter {
  List<List<String>> convert(String input) {
    List<List<String>> rows = [];
    List<String> lines = input.split(RegExp(r'\r?\n'));
    for (String line in lines) {
      if (line.trim().isEmpty) continue;
      List<String> result = [];
      bool inQuotes = false;
      StringBuffer currentField = StringBuffer();
      for (int i = 0; i < line.length; i++) {
        String char = line[i];
        if (char == '"') {
          if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
            currentField.write('"');
            i++;
          } else { inQuotes = !inQuotes; }
        } else if (char == ',' && !inQuotes) {
          result.add(currentField.toString());
          currentField.clear();
        } else { currentField.write(char); }
      }
      result.add(currentField.toString());
      rows.add(result);
    }
    return rows;
  }
}
