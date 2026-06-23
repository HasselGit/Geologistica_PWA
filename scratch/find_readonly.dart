import 'dart:io';

void main() {
  final file = File('lib/pages/paradadetalle.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('isReadOnly occurrences in paradadetalle.dart:');
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('isReadOnly')) {
      print('${i + 1}: ${lines[i].trim()}');
    }
  }
}
