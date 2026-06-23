import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('Transcript file not found.');
    return;
  }

  final lines = await file.readAsLines();
  
  // Let's print steps around the user messages 5-15 (between step 180 and 600)
  // Let's write matches for terms like "opcion", "pesaje", "SENASA", "parada", "tambor", "remito"
  for (int i = 150; i < 600; i++) {
    if (i >= lines.length) break;
    try {
      final json = jsonDecode(lines[i]);
      final type = json['type'];
      final source = json['source'];
      final content = json['content'] ?? '';
      
      if (source == 'MODEL' && (type == 'PLANNER_RESPONSE' || type == 'USER_INPUT' || type == 'CHAT_RESPONSE')) {
        final text = content.toString();
        if (text.contains('opción') || text.contains('pesado') || text.contains('SENASA') || text.contains('remito') || text.contains('parada') || text.contains('tambor')) {
          print('--- Step $i ($source / $type) ---');
          final clean = text.length > 500 ? text.substring(0, 500) + '...' : text;
          print(clean);
          print('\n');
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}
