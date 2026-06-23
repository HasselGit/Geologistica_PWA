import 'dart:io';

void main() {
  final file = File('c:/Users/Usuario/Desktop/Geologistica/lib/pages/paradadetalle.dart');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  int startFetch = -1;
  int endFetch = -1;
  int startInit = -1;
  int endInit = -1;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('Future<Map<String, dynamic>> _fetchParadaData()')) {
      startFetch = i;
    }
    if (startFetch != -1 && endFetch == -1 && line.startsWith('  }')) {
      // Find end of fetch method
      if (i > startFetch + 10) {
        endFetch = i;
      }
    }
    if (line.contains('void initState()')) {
      startInit = i;
    }
    if (startInit != -1 && endInit == -1 && line.startsWith('  }')) {
      if (i > startInit + 5) {
        endInit = i;
      }
    }
  }
  
  print('=== INIT STATE ===');
  if (startInit != -1) {
    for (int k = startInit; k <= (endInit != -1 ? endInit : startInit + 15); k++) {
      print('${k + 1}: ${lines[k]}');
    }
  }
  
  print('\n=== FETCH PARADA DATA ===');
  if (startFetch != -1) {
    for (int k = startFetch; k <= (endFetch != -1 ? endFetch : startFetch + 50); k++) {
      print('${k + 1}: ${lines[k]}');
    }
  }
}
