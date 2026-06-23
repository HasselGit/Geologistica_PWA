import 'dart:io';

void main() {
  final file = File('lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Methods and key definitions in remito_registro.dart:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.startsWith('void ') || 
        line.startsWith('Future<') || 
        line.startsWith('Widget _build') || 
        line.contains('class ') ||
        line.contains('_load') ||
        line.contains('get ') ||
        line.contains('pesajes')) {
      if (line.endsWith('{') || line.endsWith('=>') || line.endsWith('(') || line.contains('=')) {
        print('${i + 1}: $line');
      }
    }
  }
}
