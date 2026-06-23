import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/paradadetalle.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.toLowerCase().contains('receptor') || line.toLowerCase().contains('tercero') || line.toLowerCase().contains('apicultor')) {
      print('Line ${i + 1}: $line');
    }
  }
}
