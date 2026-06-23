import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  int count = 0;
  for (final line in lines) {
    try {
      final data = jsonDecode(line);
      if (data['type'] == 'USER_INPUT') {
        count++;
        print('--- User Message $count (${data['created_at']}) ---');
        print(data['content']);
        print('');
      }
    } catch (e) {
      // Ignore parse errors
    }
  }
}
