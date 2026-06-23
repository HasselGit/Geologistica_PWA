import 'dart:io';

void main() {
  final file = File('lib/pages/viaje_detalle.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Search results in viaje_detalle.dart:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].toLowerCase();
    if (line.contains('finalizar') || line.contains('remito') || line.contains('pesaje') || line.contains('tcm') || line.contains('botón') || line.contains('boton')) {
      print('${i + 1}: ${lines[i].trim()}');
    }
  }
}
