import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    print('AndroidManifest.xml does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    print('${i + 1}: ${lines[i]}');
  }
}
