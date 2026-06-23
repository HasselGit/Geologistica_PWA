import json
import os

log_path = r"C:\Users\Parque-Apicola\.gemini\antigravity\brain\75658653-c460-45d0-a25b-67da014a8803\.system_generated\logs\transcript.jsonl"

if os.path.exists(log_path):
    print("Log file exists! Reading last 50 lines containing error or print...")
    with open(log_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    count = 0
    for line in reversed(lines):
        if any(term in line.lower() for term in ['error', 'exception', 'fail', 'deposito', 'carga']):
            try:
                obj = json.loads(line)
                content = obj.get('content', '')
                if content:
                    print(f"Step {obj.get('step_index')}: {content[:500]}")
                    count += 1
                    if count >= 30:
                        break
            except Exception as e:
                pass
else:
    print("Log file does not exist.")
