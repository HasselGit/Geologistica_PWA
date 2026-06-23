import 'dart:io';

void main() {
  final file = File('lib/pages/agregar_pesaje.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('Methods of interest in agregar_pesaje.dart:');
  
  int start = -1;
  int end = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('_updatePesarStateForSelectedApicultor') || lines[i].contains('_addTambor')) {
      print('Found ${lines[i].trim()} at line ${i + 1}');
    }
  }
}
