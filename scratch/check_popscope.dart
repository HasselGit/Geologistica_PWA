import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/remito_registro.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final content = file.readAsStringSync();
  if (content.contains('PopScope') || content.contains('WillPopScope')) {
    print('Found PopScope/WillPopScope in remito_registro.dart');
  } else {
    print('No PopScope or WillPopScope found');
  }
}
