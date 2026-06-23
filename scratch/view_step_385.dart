import 'dart:convert';
import 'dart:io';

void main() {
  final file = File(r'C:\Users\Parque-Apicola\\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!file.existsSync()) {
    print('File does not exist');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (final line in lines) {
    try {
      final data = jsonDecode(line);
      final step = data['step_index'];
      if (step >= 384 && step <= 387) {
        print('--- STEP $step (${data['source']}) ---');
        print(data['content'] ?? '');
        print('==================================================\n');
      }
    } catch (e) {}
  }
}
