import os
from supabase import create_client, Client

# Fetch credentials from workspace config or environment if possible
# Let's check if we can read the supabase credentials from the dart files!
# We can search for Supabase.initialize in lib/main.dart or lib/backend/supabase_service.dart

def get_credentials():
    import re
    main_path = 'lib/main.dart'
    if not os.path.exists(main_path):
        return None, None
    with open(main_path, 'r', encoding='utf-8') as f:
        content = f.read()
    url_match = re.search(r"supabaseUrl:\s*['\"]([^'\"]+)['\"]", content)
    anon_match = re.search(r"supabaseAnonKey:\s*['\"]([^'\"]+)['\"]", content)
    if not url_match or not anon_match:
        # Try alternate match
        url_match = re.search(r"url:\s*['\"]([^'\"]+)['\"]", content)
        anon_match = re.search(r"anonKey:\s*['\"]([^'\"]+)['\"]", content)
    if url_match and anon_match:
        return url_match.group(1), anon_match.group(1)
    
    # Try lib/backend/supabase_service.dart or similar
    # Let's search lib/main.dart for any url
    print("Trying to find in main.dart manually:")
    lines = content.split('\n')
    for line in lines:
        if 'supabase' in line.lower() or 'url' in line.lower() or 'key' in line.lower():
            print(line.strip())
    return None, None

url, key = get_credentials()
print(f"Supabase URL: {url}")
if url and key:
    supabase: Client = create_client(url, key)
    # Let's fetch terminated viajes and their paradas, parada_items, remitos and solicitudes!
    print("\n--- Terminated Viajes ---")
    viajes = supabase.table('viajes').select('*').eq('estado', 'Terminado').execute()
    for v in viajes.data:
        print(f"Viaje: {v['id']} | Code: {v['viaje_codigo']} | Estado: {v['estado']}")
        paradas = supabase.table('paradas').select('*').eq('viaje_id', v['id']).execute()
        for p in paradas.data:
            print(f"  Parada: {p['id']} | Secuencia: {p['orden_secuencia']} | Estado: {p['estado']} | SolId: {p['solicitud_id']} | RemitoId: {p['remito_id']}")
            items = supabase.table('parada_items').select('*').eq('parada_id', p['id']).execute()
            for it in items.data:
                print(f"    Item: {it['producto_codigo']} | Cantidad: {it['cantidad']} | Unidad: {it['unidad']}")
            remitos = supabase.table('remitos').select('*').eq('parada_id', p['id']).execute()
            for r in remitos.data:
                print(f"    Remito: {r['id']} | Persona: {r['persona_nombre']} | PDF: {r['pdf_url']}")
            # Fetch solicitudes matching this parada_id short code
            short_id = p['id'].split('-')[0].upper()
            sol_filters = []
            if p['solicitud_id']:
                sol_filters.append(f"id.eq.{p['solicitud_id']}")
            sol_filters.append(f"solicitud_codigo.ilike.SOL-REM-{short_id}%")
            
            # Simple select first
            all_sols = supabase.table('solicitudes').select('*').execute()
            matching_sols = [s for s in all_sols.data if (p['solicitud_id'] and s['id'] == p['solicitud_id']) or s['solicitud_codigo'].startswith(f"SOL-REM-{short_id}")]
            for s in matchingSols:
                print(f"    Solicitud: {s['id']} | Code: {s['solicitud_codigo']} | Prod: {s['producto']} | Cant: {s['cantidad']} | Estado: {s['estado']}")
else:
    print("Could not retrieve credentials.")
