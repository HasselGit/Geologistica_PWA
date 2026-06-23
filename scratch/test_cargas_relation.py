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

print("=== TESTING CARGAS + CARGA_ITEMS RELATION QUERY ===")

select_query = 'id,carga_codigo,viaje_id,estado,created_at,updated_at,carga_items(id,producto_codigo,cantidad,unidad)'
path = f"/rest/v1/cargas?select={urllib.parse.quote(select_query)}"

status, res = make_request(path)
print(f"Status: {status}")
if status == 200:
    print(f"Success! Found {len(res)} cargas.")
    for c in res:
        print(f"Carga: {c.get('carga_codigo')} | Estado: {c.get('estado')}")
        items = c.get('carga_items') or []
        print(f"  Items ({len(items)}):")
        for it in items:
            print(f"    - Prod: {it.get('producto_codigo')} | Qty: {it.get('cantidad')} | Unit: {it.get('unidad')}")
else:
    print(f"FAILED: {status} - {res}")
