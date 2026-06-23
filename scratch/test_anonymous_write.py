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

print("=== TESTING ANONYMOUS WRITE OPERATIONS VIA REST API (URLLIB) ===")

print("\n1. Selecting profiles...")
status, profiles = make_request('/rest/v1/profiles')
if status == 200:
    print(f"Profiles count: {len(profiles)}")
    for p in profiles:
        print(f"  Name: {p.get('nombre')} {p.get('apellido')} | Puesto: {p.get('puesto')} | Rol: {p.get('rol')} | Email: {p.get('email')}")
else:
    print(f"Failed: {status} - {profiles}")

print("\n2. Selecting viajes...")
status, viajes = make_request('/rest/v1/viajes')
if status == 200:
    print(f"Viajes count: {len(viajes)}")
    for v in viajes:
        print(f"  Viaje: {v.get('viaje_codigo')} | Estado: {v.get('estado')}")
else:
    print(f"Failed: {status} - {viajes}")

print("\n3. Selecting cargas...")
status, cargas = make_request('/rest/v1/cargas')
if status == 200:
    print(f"Cargas count: {len(cargas)}")
    for c in cargas:
        print(f"  Carga: {c.get('carga_codigo')} | Estado: {c.get('estado')}")
else:
    print(f"Failed: {status} - {cargas}")

print("\n4. Trying to update a carga's state (CARGA-7845001)...")
c_id = None
if status == 200 and cargas:
    for c in cargas:
        if c.get('carga_codigo') == 'CARGA-7845001':
            c_id = c.get('id')
            break

if c_id:
    # Use PATCH to update
    status_upd, res_upd = make_request(f'/rest/v1/cargas?id=eq.{c_id}', method='PATCH', data={'estado': 'Terminado'})
    print(f"PATCH status: {status_upd}, response: {res_upd}")
    if status_upd in (200, 201, 204):
        print("Update succeeded!")
        # Revert update
        make_request(f'/rest/v1/cargas?id=eq.{c_id}', method='PATCH', data={'estado': 'Pendiente'})
    else:
        print(f"Update failed!")
else:
    print("CARGA-7845001 not found to test update.")
