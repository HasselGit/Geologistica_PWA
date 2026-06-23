import os
import sys
import json

def main():
    sys.stdout.reconfigure(encoding='utf-8')
    filepath = r"C:\Users\Parque-Apicola\.gemini\antigravity\brain\a14dcd5d-fb28-4f31-89c7-9baa2b389c91\.system_generated\logs\overview.txt"
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as file:
            lines = file.readlines()
        
        printing = False
        count = 0
        for line in lines:
            try:
                data = json.loads(line)
                step = data.get("step_index", 0)
                if step >= 85 and step <= 130:
                    print(f"--- STEP {step} ({data.get('type')}, {data.get('source')}) ---")
                    content = data.get("content", "")
                    if content:
                        print(content[:600] + ("..." if len(content) > 600 else ""))
                    tc = data.get("tool_calls", [])
                    if tc:
                        print(f"Tool calls: {json.dumps(tc, indent=2)}")
                    print("-" * 60)
            except Exception as e:
                pass
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
