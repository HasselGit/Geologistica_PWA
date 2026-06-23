import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File(r'C:\Users\Parque-Apicola\.gemini\antigravity\brain\9d0dc90c-94b5-46b2-bfdd-a3c3057dea72\.system_generated\logs\transcript.jsonl');
  if (!await file.exists()) {
    print('Transcript file not found.');
    return;
  }

  final lines = await file.readAsLines();
  if (lines.length > 207) {
    try {
      final json = jsonDecode(lines[207]);
      print('=== Step 207 ===');
      print(json['content']);
    } catch (e) {
      print('Error parsing step 207: $e');
    }
  } else {
    print('Line 207 does not exist. Total lines: ${lines.length}');
  }
}
