import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/paradadetalle.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  int start = -1;
  int end = -1;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('FutureBuilder<Map<String, dynamic>?>(')) {
      start = i;
      break;
    }
  }
  
  if (start != -1) {
    for (int k = start; k < start + 60; k++) {
      if (k >= 0 && k < lines.length) {
        print('${k + 1}: ${lines[k]}');
      }
    }
  }
}
