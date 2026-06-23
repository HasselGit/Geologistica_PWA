import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('Transcript file not found.');
    return;
  }

  final lines = await file.readAsLines();
  print('Transcript range [380, 470]:');
  for (int i = 380; i <= 470; i++) {
    if (i >= lines.length) break;
    try {
      final json = jsonDecode(lines[i]);
      final type = json['type'];
      final source = json['source'];
      final content = json['content'] ?? '';
      
      if (source == 'USER_EXPLICIT' || type == 'USER_INPUT' || source == 'MODEL' && (type == 'PLANNER_RESPONSE' || type == 'CHAT_RESPONSE')) {
        print('--- Step $i ($source / $type) ---');
        print(content);
        print('\n');
      }
    } catch (e) {
      // Ignore
    }
  }
}
