import 'dart:io';

void main() {
  final file = File('lib/backend/pdf_invoice_generator.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('generateWeighingRemitoPDF Part 2:');
  for (int i = 649; i < 750; i++) {
    if (i < lines.length) {
      print('${i + 1}: ${lines[i]}');
    }
  }
}
