import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Creando Buckets y configurando RLS en Supabase ---');

  final sqlCommands = '''
    -- 1. Insertar buckets en la tabla de storage.buckets
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('remitos', 'remitos', true, null, null)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('gastos', 'gastos', true, null, null)
    ON CONFLICT (id) DO NOTHING;

    -- 2. Asegurar que las políticas RLS permitan acceso completo a public en remitos
    DROP POLICY IF EXISTS "Allow public access to remitos" ON storage.objects;
    CREATE POLICY "Allow public access to remitos" ON storage.objects
    FOR ALL TO public
    USING (bucket_id = 'remitos')
    WITH CHECK (bucket_id = 'remitos');

    -- 3. Asegurar que las políticas RLS permitan acceso completo a public en gastos
    DROP POLICY IF EXISTS "Allow public access to gastos" ON storage.objects;
    CREATE POLICY "Allow public access to gastos" ON storage.objects
    FOR ALL TO public
    USING (bucket_id = 'gastos')
    WITH CHECK (bucket_id = 'gastos');
  ''';

  try {
    final res = await client.rpc('exec_sql', params: {
      'sql': sqlCommands,
    });
    print('Éxito! Resultado del servidor: $res');
  } catch (e) {
    print('Error al ejecutar RPC: $e');
  }
}
