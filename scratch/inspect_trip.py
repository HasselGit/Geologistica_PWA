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

trip_id = "ebcbcae8-e802-4733-9e0e-639d3861f29c"

print("VIAJE:")
viaje = query_table("viajes", f"id=eq.{trip_id}")
print(json.dumps(viaje, indent=2))

print("\nPARADAS:")
paradas = query_table("paradas", f"viaje_id=eq.{trip_id}")
print(json.dumps(paradas, indent=2))

for p in paradas:
    p_id = p['id']
    print(f"\nPARADA ITEMS FOR {p_id}:")
    p_items = query_table("parada_items", f"parada_id=eq.{p_id}")
    print(json.dumps(p_items, indent=2))
    
    if p['solicitud_id']:
        sol_id = p['solicitud_id']
        print(f"\nSOLICITUD FOR {sol_id}:")
        sol = query_table("solicitudes", f"id=eq.{sol_id}")
        print(json.dumps(sol, indent=2))
