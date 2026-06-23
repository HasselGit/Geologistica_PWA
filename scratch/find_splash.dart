import 'dart:io';

void main() {
  final brainDir = Directory(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\75658653-c460-45d0-a25b-67da014a8803');
  if (!brainDir.existsSync()) {
    print('Brain directory not found');
    return;
  }
  
  final files = brainDir.listSync();
  final List<File> pngFiles = [];
  
  for (final entity in files) {
    if (entity is File && entity.path.endsWith('.png')) {
      pngFiles.add(entity);
    }
  }
  
  // Sort by modification time
  pngFiles.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
  
  print('PNG FILES IN BRAIN DIRECTORY (SORTED BY DATE):');
  for (final file in pngFiles) {
    print('Path: ${file.path}');
    print('  Size: ${file.lengthSync()} bytes');
    print('  Modified: ${file.lastModifiedSync()}');
  }
}
