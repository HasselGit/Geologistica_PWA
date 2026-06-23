import urllib.request
import json

url = "https://suwcqdlxnmfcvmlnzizl.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o"

def query_table(path, query_params=""):
    req_url = f"{url}/rest/v1/{path}"
    if query_params:
        req_url += f"?{query_params}"
    req = urllib.request.Request(
        req_url,
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}"
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        print(f"Error querying {path}: {e}")
        return None

rutas = query_table("rutas")
print(f"TOTAL RUTAS: {len(rutas)}")
for r in rutas:
    print(json.dumps(r, indent=2))
