import urllib.request
import urllib.parse
import json

url = 'https://suwcqdlxnmfcvmlnzizl.supabase.co'
anon_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o'

headers = {
    'apikey': anon_key,
    'Authorization': f'Bearer {anon_key}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

def make_request(path, method='GET', data=None):
    req_url = f"{url}{path}"
    req_data = json.dumps(data).encode('utf-8') if data is not None else None
    req = urllib.request.Request(req_url, headers=headers, method=method, data=req_data)
    try:
        with urllib.request.urlopen(req) as response:
            res_data = response.read().decode('utf-8')
            return response.status, json.loads(res_data) if res_data else None
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except Exception as e:
        return 0, str(e)

print("=== INSPECTING GEOLOGISTICA DATABASE ===")

print("\n--- profiles ---")
status, profiles = make_request('/rest/v1/profiles')
if status == 200:
    for p in profiles:
        print(f"ID: {p.get('id')} | Email: {p.get('email')} | Name: {p.get('nombre')} {p.get('apellido')} | Puesto: {p.get('puesto')} | Rol: {p.get('rol')} | Pass: {p.get('contrasena')}")
else:
    print(f"Failed: {status} - {profiles}")

print("\n--- viajes ---")
status, viajes = make_request('/rest/v1/viajes')
if status == 200:
    for v in viajes:
        print(f"ID: {v.get('id')} | Code: {v.get('viaje_codigo')} | Chofer ID: {v.get('chofer_id')} | Estado: {v.get('estado')} | Vehículo: {v.get('vehiculo_codigo')}")
else:
    print(f"Failed: {status} - {viajes}")

print("\n--- cargas ---")
status, cargas = make_request('/rest/v1/cargas')
if status == 200:
    for c in cargas:
        print(f"ID: {c.get('id')} | Code: {c.get('carga_codigo')} | Viaje ID: {c.get('viaje_id')} | Estado: {c.get('estado')}")
else:
    print(f"Failed: {status} - {cargas}")

print("\n--- active/pending loads ---")
status, active_cargas = make_request('/rest/v1/cargas?estado=eq.Pendiente')
if status == 200:
    for c in active_cargas:
        print(f"Carga: {c.get('carga_codigo')} (Viaje: {c.get('viaje_id')}) | Estado: {c.get('estado')}")
else:
    print(f"Failed: {status} - {active_cargas}")
