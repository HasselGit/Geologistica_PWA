import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Total lines: ${lines.length}');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('pop') || line.contains('Navigator') || line.contains('context') || line.contains('go(')) {
      print('Line ${i + 1}: $line');
    }
  }
}
