import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 270; i < 395; i++) {
    final line = lines[i];
    if (line.toLowerCase().contains('apicultor') || line.toLowerCase().contains('dni') || line.toLowerCase().contains('widget') || line.toLowerCase().contains('nombre')) {
      print('Line ${i + 1}: $line');
    }
  }
}
