import 'dart:io';
import 'dart:convert';

void main() {
  final transcriptFile = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\75658653-c460-45d0-a25b-67da014a8803\.system_generated\logs\transcript.jsonl');
  if (!transcriptFile.existsSync()) {
    print('Transcript file not found');
    return;
  }
  
  final lines = transcriptFile.readAsLinesSync();
  final outputFile = File('scratch/option_1_details.txt');
  final IOSink sink = outputFile.openWrite();
  
  sink.writeln('SEARCH RESULTS FOR SPLASH SCREEN OPTIONS IN TRANSCRIPT LOGS');
  sink.writeln('===========================================================');
  
  for (int i = 0; i < lines.length; i++) {
    try {
      final Map<String, dynamic> data = jsonDecode(lines[i]);
      final String content = data['content']?.toString() ?? '';
      
      if (content.toLowerCase().contains('splash') || 
          content.toLowerCase().contains('opción') || 
          content.toLowerCase().contains('opcion') || 
          content.toLowerCase().contains('versión') ||
          content.toLowerCase().contains('version') ||
          content.toLowerCase().contains('propuesta')) {
        sink.writeln('\n\n=============================================');
        sink.writeln('MATCH AT STEP INDEX $i (Type: ${data['type']}, Source: ${data['source']})');
        sink.writeln('=============================================');
        sink.writeln(content);
      }
    } catch (e) {
      // Ignored
    }
  }
  
  sink.close();
  print('Saved search results to scratch/option_1_details.txt');
}
