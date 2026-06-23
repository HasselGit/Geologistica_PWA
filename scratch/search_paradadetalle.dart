import 'dart:io';

void main() {
  final file = File('lib/pages/paradadetalle.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Search results in paradadetalle.dart:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].toLowerCase();
    if (line.contains('finalizar') || line.contains('remito') || line.contains('pesaje') || line.contains('tcm') || line.contains('boton') || line.contains('botón')) {
      print('${i + 1}: ${lines[i].trim()}');
    }
  }
}
