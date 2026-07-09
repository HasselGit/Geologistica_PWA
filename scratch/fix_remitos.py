import os
from supabase import create_client, Client

url = "https://suwcqdlxnmfcvmlnzizl.supabase.co"
key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o"

supabase = create_client(url, key)

# 1. Fetch Zupan and Urrutia IDs
print("Fetching Apicultores...")
apic = supabase.table('apicultores').select('id, nombre').execute()
zupan_id = None
urrutia_id = None
for a in apic.data:
    if "Zupan" in a['nombre']:
        zupan_id = a['id']
    if "Urrutia" in a['nombre']:
        urrutia_id = a['id']

print(f"Zupan ID: {zupan_id}")
print(f"Urrutia ID: {urrutia_id}")

if not zupan_id or not urrutia_id:
    print("Could not find IDs")
    exit()

# 2. Fetch the remitos
print("Fetching Remitos...")
remitos = supabase.table('remitos').select('id, remito_codigo, apicultor_id').execute()

for r in remitos.data:
    code = r['remito_codigo']
    if code == 'REM-BE721654-2':
        print(f"Found Zupan Remito: {r['id']}, updating apicultor_id to {zupan_id}")
        res = supabase.table('remitos').update({'apicultor_id': zupan_id}).eq('id', r['id']).execute()
        print(res.data)
    elif code == 'REM-BE721654':
        print(f"Found Urrutia Remito: {r['id']}, updating apicultor_id to {urrutia_id}")
        res = supabase.table('remitos').update({'apicultor_id': urrutia_id}).eq('id', r['id']).execute()
        print(res.data)

print("Done!")
