import 'dart:io';

void main() {
  final file = File('lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('remito_id and table updates in remito_registro.dart:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].toLowerCase();
    if (line.contains('remito_id') || line.contains('update') || line.contains('paradas')) {
      print('${i + 1}: ${lines[i].trim()}');
    }
  }
}
