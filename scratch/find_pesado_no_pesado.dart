import 'dart:io';

void main() {
  final file = File('prompts_historico_consolidado.txt');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Search results for "pesado" or "pesajes":');
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].toLowerCase();
    if (line.contains('pesado') || line.contains('no pesar') || line.contains('sin pesar')) {
      print('Line ${i + 1}:');
      for (int j = i - 3; j <= i + 3; j++) {
        if (j >= 0 && j < lines.length) {
          print('  [${j + 1}] ${lines[j]}');
        }
      }
      print('-----------------');
      i += 3;
    }
  }
}
