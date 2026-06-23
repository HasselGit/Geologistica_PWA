import os
import re
from supabase import create_client, Client

url = 'https://suwcqdlxnmfcvmlnzizl.supabase.co'
key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o'

supabase: Client = create_client(url, key)

print("--- VEHICLES STATUS ---")
vehs = supabase.table('vehiculos').select('*').execute()
for v in vehs.data:
    print(f"Vehículo: {v['vehiculo_codigo']} | Capacidad KG: {v['capacidad_kg']} | Capacidad Tambores: {v['capacidad_tambores']} | Actual KG: {v['carga_actual_kg']} | Actual Tambores: {v['carga_actual_tambores']}")

print("\n--- CARGAS STATUS ---")
cargas = supabase.table('cargas').select('*, carga_items(*)').execute()
for c in cargas.data:
    print(f"Carga: {c['carga_codigo']} | ID: {c['id']} | ViajeID: {c['viaje_id']} | Estado: {c['estado']}")
    print(f"  Items: {c['carga_items']}")

print("\n--- VIAJES STATUS ---")
viajes = supabase.table('viajes').select('*').execute()
for v in viajes.data:
    print(f"Viaje: {v['viaje_codigo']} | ID: {v['id']} | Vehículo: {v['vehiculo_codigo']} | ChoferID: {v['chofer_id']} | Estado: {v['estado']}")
