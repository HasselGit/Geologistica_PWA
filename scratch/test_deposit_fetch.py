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

print("=== SIMULATING DEPOSITOHOME FETCHDATA VIA REST ===")

# 1. Fetch pending viajes
print("\n1. Querying viajes where estado=Pendiente with select...")
# In Dart:
# select('*, paradas(*, parada_items(*)), vehiculos:vehiculo_codigo(capacidad_kg, capacidad_tambores), cargas(id, carga_codigo, estado, carga_items(*))')
select_str = "*,paradas(*,parada_items(*)),vehiculos:vehiculo_codigo(capacidad_kg,capacidad_tambores),cargas(id,carga_codigo,estado,carga_items(*))"
path = f"/rest/v1/viajes?select={urllib.parse.quote(select_str)}&estado=eq.Pendiente&order=fecha.asc"

status, res = make_request(path)
print(f"Status: {status}")
if status != 200:
    print(f"FAILED TO FETCH VIAJES: {res}")
else:
    print(f"Fetched {len(res)} viajes.")
    for v in res:
        print(f"\nViaje Code: {v.get('viaje_codigo')} | ID: {v.get('id')} | Estado: {v.get('estado')}")
        chofer_id = v.get('chofer_id')
        if chofer_id:
            c_status, chofer = make_request(f"/rest/v1/profiles?select=nombre,apellido&id=eq.{chofer_id}")
            if c_status == 200 and chofer:
                print(f"  Chofer: {chofer[0].get('nombre')} {chofer[0].get('apellido')}")
            else:
                print(f"  Chofer ID {chofer_id} query status: {c_status} - {chofer}")
        
        cargas = v.get('cargas') or []
        print(f"  Cargas (length: {len(cargas)}):")
        for c in cargas:
            print(f"    - Carga: {c.get('carga_codigo')} | Estado: {c.get('estado')} | Items: {c.get('carga_items')}")

# 2. Fetch terminated cargas (tab 2)
print("\n2. Querying terminated cargas...")
select_cargas = "*,viaje:viaje_id(*,vehiculo:vehiculo_codigo(*)),carga_items(*)"
path_cargas = f"/rest/v1/cargas?select={urllib.parse.quote(select_cargas)}&estado=eq.Terminado&order=updated_at.desc"
status_c, res_c = make_request(path_cargas)
print(f"Status: {status_c}")
if status_c != 200:
    print(f"FAILED TO FETCH TERMINATED CARGAS: {res_c}")
else:
    print(f"Fetched {len(res_c)} terminated cargas.")

# 3. Fetch products
print("\n3. Querying products...")
status_p, res_p = make_request("/rest/v1/productos?select=id,descripcion,codigo,unidad,activo&order=descripcion.asc")
print(f"Status: {status_p}")
if status_p != 200:
    print(f"FAILED TO FETCH PRODUCTS: {res_p}")
else:
    print(f"Fetched {len(res_p)} products.")
