import 'dart:io';

void main() {
  final dir = Directory('c:/Users/Usuario/Desktop/Geologistica/lib');
  if (!dir.existsSync()) {
    print('Lib directory does not exist');
    return;
  }
  
  dir.listSync(recursive: true).forEach((entity) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      if (content.contains('from(\'apicultores\')')) {
        print('Found query in ${entity.path}:');
        final lines = content.split('\n');
        for (int i = 0; i < lines.length; i++) {
          if (lines[i].contains('from(\'apicultores\')')) {
            for (int k = i - 1; k < i + 8; k++) {
              if (k >= 0 && k < lines.length) {
                print('  ${k + 1}: ${lines[k]}');
              }
            }
          }
        }
      }
    }
  });
}
