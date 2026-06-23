import json
import urllib.request

url = 'https://suwcqdlxnmfcvmlnzizl.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o'

headers = {
    'apikey': key,
    'Authorization': f'Bearer {key}'
}

def query_supabase(table, select='*'):
    req_url = f"{url}/rest/v1/{table}?select={select}"
    req = urllib.request.Request(req_url, headers=headers)
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        print(f"Error querying {table}: {e}")
        return []

print("--- VEHICLES STATUS ---")
vehs = query_supabase('vehiculos')
for v in vehs:
    print(f"Vehículo: {v.get('vehiculo_codigo')} | Capacidad KG: {v.get('capacidad_kg')} | Capacidad Tambores: {v.get('capacidad_tambores')} | Actual KG: {v.get('carga_actual_kg')} | Actual Tambores: {v.get('carga_actual_tambores')}")

print("\n--- CARGAS STATUS ---")
cargas = query_supabase('cargas', '*,carga_items(*)')
for c in cargas:
    print(f"Carga: {c.get('carga_codigo')} | ID: {c.get('id')} | ViajeID: {c.get('viaje_id')} | Estado: {c.get('estado')}")
    print(f"  Items: {c.get('carga_items')}")

print("\n--- VIAJES STATUS ---")
viajes = query_supabase('viajes')
for v in viajes:
    print(f"Viaje: {v.get('viaje_codigo')} | ID: {v.get('id')} | Vehículo: {v.get('vehiculo_codigo')} | ChoferID: {v.get('chofer_id')} | Estado: {v.get('estado')}")
