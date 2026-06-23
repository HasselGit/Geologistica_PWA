import 'dart:io';

void main() {
  final file = File('prompts_historico_consolidado.txt');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Search results in prompts_historico_consolidado.txt:');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].toLowerCase();
    if (line.contains('senasa') || line.contains('pesaje') || line.contains('tambor')) {
      // Print context: line and 2 lines around it
      print('Line ${i + 1}:');
      for (int j = i - 2; j <= i + 2; j++) {
        if (j >= 0 && j < lines.length) {
          print('  [${j + 1}] ${lines[j]}');
        }
      }
      print('-----------------');
      i += 2; // Skip printed lines
    }
  }
}
