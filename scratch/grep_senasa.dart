import 'dart:io';

void main() {
  final file = File('lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].toLowerCase().contains('senasa')) {
      print('${i + 1}: ${lines[i].trim()}');
    }
  }
}
