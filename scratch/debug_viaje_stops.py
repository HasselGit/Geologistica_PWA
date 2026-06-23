import urllib.request
import urllib.parse
import json

url_base = 'https://suwcqdlxnmfcvmlnzizl.supabase.co/rest/v1'
api_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o'

def query(table, params):
    qs = urllib.parse.urlencode(params)
    url = f"{url_base}/{table}?{qs}"
    req = urllib.request.Request(
        url,
        headers={
            'apikey': api_key,
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json'
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            res_body = response.read().decode('utf-8')
            return json.loads(res_body)
    except Exception as e:
        print("Error:", str(e))
        return []

print("--- BUSCANDO PERFILES DE DEPOSITO Y MANAGEMENT ---")
profiles = query("profiles", {"select": "id,nombre,apellido,puesto,email"})
for p in profiles:
    print(f"Nombre: {p.get('nombre')} {p.get('apellido')} - Puesto: '{p.get('puesto')}' - Email: {p.get('email')}")
