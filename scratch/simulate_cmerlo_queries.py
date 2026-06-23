import urllib.request
import json

url = "https://suwcqdlxnmfcvmlnzizl.supabase.co"
anon_key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o"

def login(email, password):
    login_url = f"{url}/auth/v1/token?grant_type=password"
    data = json.dumps({"email": email, "password": password}).encode('utf-8')
    req = urllib.request.Request(
        login_url,
        data=data,
        headers={
            "apikey": anon_key,
            "Content-Type": "application/json"
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            res_data = json.loads(response.read().decode('utf-8'))
            return res_data["access_token"]
    except Exception as e:
        print(f"Error logging in as {email}: {e}")
        return None

def query_table_as_user(token, path, query_params=""):
    req_url = f"{url}/rest/v1/{path}"
    if query_params:
        req_url += f"?{query_params}"
    req = urllib.request.Request(
        req_url,
        headers={
            "apikey": anon_key,
            "Authorization": f"Bearer {token}"
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode('utf-8'))
    except Exception as e:
        print(f"Error querying {path} as user: {e}")
        if hasattr(e, 'read'):
            print("Error details:", e.read().decode('utf-8'))
        return None

token = login("cmerlo@geomiel.com", "cmerlo")
if token:
    print("Logged in successfully!")
    
    trip_id = "ebcbcae8-e802-4733-9e0e-639d3861f29c"
    
    print("\nQuerying viajes:")
    viaje = query_table_as_user(token, "viajes", f"id=eq.{trip_id}")
    print("Viaje result:", viaje)
    
    print("\nQuerying rutas:")
    rutas = query_table_as_user(token, "rutas", f"viaje_id=eq.{trip_id}")
    print("Rutas result:", rutas)
    
    print("\nQuerying paradas:")
    paradas = query_table_as_user(token, "paradas", f"viaje_id=eq.{trip_id}")
    print("Paradas result:", paradas)
    
    print("\nQuerying cargas:")
    cargas = query_table_as_user(token, "cargas", f"viaje_id=eq.{trip_id}")
    print("Cargas result:", cargas)
    
    print("\nQuerying profiles for chofer:")
    chofer = query_table_as_user(token, "profiles", "id=eq.d96485ce-0003-48e9-be14-b5de638063b4")
    print("Chofer result:", chofer)
else:
    print("Login failed.")
