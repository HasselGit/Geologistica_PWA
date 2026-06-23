import 'dart:io';

void main() async {
  print('--- Analizando código de producción ---');
  final result = await Process.run('flutter', ['analyze'], workingDirectory: 'c:/Users/Usuario/Desktop/Geologistica');
  final lines = result.stdout.toString().split('\n');
  
  int errorsCount = 0;
  for (var line in lines) {
    if (line.contains('error -')) {
      print(line);
      errorsCount++;
    }
  }
  
  print('-----------------------------------------');
  print('Total de errores críticos de compilación encontrados: $errorsCount');
}
