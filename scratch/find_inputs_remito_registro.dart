import 'dart:io';

void main() {
  final file = File('lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Text fields in remito_registro.dart:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.contains('TextFormField') || line.contains('TextField') || line.contains('TextEditingController')) {
      print('${i + 1}: $line');
    }
  }
}
