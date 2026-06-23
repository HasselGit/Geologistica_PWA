import 'dart:typed_data';
import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Probando Subida a "remitos" ---');
  final testBytes = Uint8List.fromList([72, 101, 108, 108, 111]); // 'Hello'
  final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';

  try {
    // 1. Intentar subir el archivo binario
    await client.storage.from('remitos').uploadBinary(
      fileName,
      testBytes,
      fileOptions: const FileOptions(contentType: 'text/plain'),
    );
    print('  [ÉXITO] Archivo subido: $fileName');

    // 2. Obtener URL pública
    final publicUrl = client.storage.from('remitos').getPublicUrl(fileName);
    print('  [ÉXITO] URL pública: $publicUrl');

    // 3. Limpiar archivo de prueba
    await client.storage.from('remitos').remove([fileName]);
    print('  [ÉXITO] Archivo de prueba eliminado del servidor.');
  } catch (e) {
    print('  [FAIL] La prueba de almacenamiento falló: $e');
  }
}
