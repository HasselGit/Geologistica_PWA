import 'dart:io';

void main() {
  final file = File('lib/backend/pdf_invoice_generator.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('generateWeighingRemitoPDF in pdf_invoice_generator.dart:');
  
  int start = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('generateWeighingRemitoPDF')) {
      start = i;
      break;
    }
  }
  
  if (start != -1) {
    for (int i = start; i < start + 150; i++) {
      if (i < lines.length) {
        print('${i + 1}: ${lines[i]}');
      }
    }
  } else {
    print('Method not found.');
  }
}
