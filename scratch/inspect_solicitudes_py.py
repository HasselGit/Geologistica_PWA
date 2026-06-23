import requests
import json

url = 'https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1/solicitudes'
headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

# 1. Obtener todas las solicitudes
print("--- OBTENIENDO SOLICITUDES VIA REST API ---")
response = requests.get(url + "?select=*,apicultores(*)", headers=headers)
if response.status_code == 200:
    solicitudes = response.json()
    print(f"Total solicitudes: {len(solicitudes)}")
    for s in solicitudes:
        api = s.get('apicultores', {})
        api_nombre = f"{api.get('nombre', '')} {api.get('apellido', '')}" if api else "Sin apicultor"
        print(f"ID: {s['id']} | Apicultor: {api_nombre} ({s.get('apicultor_id')}) | Producto: {s.get('producto')} | Cantidad: {s.get('cantidad')} | Estado: {s.get('estado')} | Tipo: {s.get('tipo')} | Localidad: {s.get('localidad')}")
else:
    print(f"Error al obtener solicitudes: {response.status_code} - {response.text}")
