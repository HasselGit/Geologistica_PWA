import os
import sys

def main():
    sys.stdout.reconfigure(encoding='utf-8')
    brain_dir = r"C:\Users\Parque-Apicola\.gemini\antigravity\brain"
    for r, d, fs in os.walk(brain_dir):
        for f in fs:
            if "overview.txt" not in f:
                continue
            filepath = os.path.join(r, f)
            if "a14dcd5d" not in filepath and "95e53651" not in filepath and "75658653" not in filepath:
                continue
            try:
                with open(filepath, "r", encoding="utf-8", errors="ignore") as file:
                    lines = file.readlines()
                for i, line in enumerate(lines):
                    if "descarga" in line.lower():
                        print(f"=== MATCH IN FILE: {os.path.basename(os.path.dirname(os.path.dirname(filepath)))} line {i+1} ===")
                        start = max(0, i - 3)
                        end = min(len(lines), i + 4)
                        for j in range(start, end):
                            print(f"{j+1}: {lines[j].strip()[:300]}")
                        print("=" * 60)
            except Exception as e:
                print(f"Error reading {filepath}: {e}")

if __name__ == "__main__":
    main()
