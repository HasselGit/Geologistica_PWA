import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('Transcript file not found.');
    return;
  }

  final lines = await file.readAsLines();
  print('Recent conversation steps (from 600 to end):');
  
  for (int i = 600; i < lines.length; i++) {
    try {
      final json = jsonDecode(lines[i]);
      final type = json['type'];
      final source = json['source'];
      final content = json['content'] ?? '';
      
      if (source == 'USER_EXPLICIT' || type == 'USER_INPUT' || source == 'MODEL' && (type == 'PLANNER_RESPONSE' || type == 'CHAT_RESPONSE')) {
        print('--- Step $i ($source / $type) ---');
        final text = content.toString();
        final clean = text.length > 500 ? text.substring(0, 500) + '...' : text;
        print(clean);
        print('\n');
      }
    } catch (e) {
      // Ignore
    }
  }
}
