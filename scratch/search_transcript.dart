import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('Transcript file not found.');
    return;
  }

  final lines = await file.readAsLines();
  print('Total lines in transcript: ${lines.length}');
  
  // Let's search for lines containing USER_INPUT type to see user requests
  for (int i = 0; i < lines.length; i++) {
    try {
      final json = jsonDecode(lines[i]);
      final type = json['type'];
      final source = json['source'];
      final content = json['content'] ?? '';
      
      if (source == 'USER_EXPLICIT' || type == 'USER_INPUT' || content.toString().contains('SENASA') || content.toString().contains('parada')) {
        print('--- Step $i (${json['source']} / ${json['type']}) ---');
        final cleanContent = content.toString().length > 300 ? content.toString().substring(0, 300) + '...' : content.toString();
        print(cleanContent);
      }
    } catch (e) {
      // Ignore parse errors
    }
  }
}
