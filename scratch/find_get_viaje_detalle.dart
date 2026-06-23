import 'dart:io';

void main() {
  final file = File('lib/backend/supabase_service.dart');
  if (!file.existsSync()) {
    print('File not found.');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('getViajeDetalle in supabase_service.dart:');
  
  int start = -1;
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('getViajeDetalle')) {
      start = i;
      break;
    }
  }
  
  if (start != -1) {
    for (int i = start; i < start + 120; i++) {
      if (i < lines.length) {
        print('${i + 1}: ${lines[i]}');
      }
    }
  } else {
    print('Method not found.');
  }
}
