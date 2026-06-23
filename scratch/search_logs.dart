import 'dart:io';
import 'dart:convert';

void main() async {
  final file = File(r'C:\Users\Usuario\.gemini\antigravity\brain\843b66ea-1ea7-4c5a-a718-ed81b5c2a5a0\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('Transcript file does not exist');
    return;
  }

  final lines = await file.readAsLines();
  final results = <String>[];
  
  final keywords = ['service_role', 'password', 'contraseña', 'postgres', 'db_password', 'db_pass', 'admin_key'];
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final kw in keywords) {
      if (line.toLowerCase().contains(kw.toLowerCase())) {
        results.add('Line $i matches "$kw":');
        try {
          final parsed = jsonDecode(line);
          final content = parsed['content']?.toString() ?? '';
          if (content.isNotEmpty) {
            results.add('  Content: $content');
          }
          final toolCalls = parsed['tool_calls']?.toString() ?? '';
          if (toolCalls.isNotEmpty) {
            results.add('  ToolCalls: $toolCalls');
          }
        } catch (_) {
          results.add('  Raw: $line');
        }
        results.add('-----------------------------------------');
        break;
      }
    }
  }

  await File(r'c:\Users\Usuario\Desktop\Geologistica\scratch\results.txt').writeAsString(results.join('\n'));
  print('Done! Matches written to scratch/results.txt. Total matches: ${results.length ~/ 3}');
}
