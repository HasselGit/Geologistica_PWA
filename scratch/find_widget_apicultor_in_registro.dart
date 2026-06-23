import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('widget.apicultorId') || line.contains('widget.apicultorNombre') || line.contains('widget.apicultorDni')) {
      print('Line ${i + 1}: $line');
    }
  }
}
