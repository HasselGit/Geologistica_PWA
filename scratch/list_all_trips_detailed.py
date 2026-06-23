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

viajes = query_table("viajes")
print(f"TOTAL TRIPS: {len(viajes)}")
for v in viajes:
    v_id = v['id']
    paradas = query_table("paradas", f"viaje_id=eq.{v_id}")
    cargas = query_table("cargas", f"viaje_id=eq.{v_id}")
    print(f"Trip: {v['viaje_codigo']} ({v['estado']}), ID: {v_id}, Date: {v['fecha']}, Vehiculo: {v['vehiculo_codigo']}")
    print(f"  Paradas count: {len(paradas) if paradas else 0}")
    print(f"  Cargas count: {len(cargas) if cargas else 0}")
    if cargas:
        for c in cargas:
            items = query_table("carga_items", f"carga_id=eq.{c['id']}")
            print(f"    Carga: {c['carga_codigo']} ({c['estado']}), ID: {c['id']}, Items: {len(items)}")
            for item in items:
                print(f"      Item: {item['producto_codigo']} x {item['cantidad']}")
