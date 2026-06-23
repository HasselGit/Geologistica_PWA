import 'dart:io';

void main() {
  final file = File('lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Buttons in remito_registro.dart:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.contains('ElevatedButton') || line.contains('TextButton') || line.contains('OutlinedButton') || line.contains('ElevatedButton.icon') || line.contains('OutlinedButton.icon')) {
      print('Line ${i + 1}:');
      for (int j = i - 1; j <= i + 5; j++) {
        if (j >= 0 && j < lines.length) {
          print('  [${j + 1}] ${lines[j]}');
        }
      }
      print('-----------------');
      i += 5;
    }
  }
}
