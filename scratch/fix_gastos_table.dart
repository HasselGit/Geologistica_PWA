import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  print('--- Creando Tabla gastos y configurando RLS y Storage en Supabase ---');

  final sql = '''
    -- 1. Crear tabla gastos si no existe
    CREATE TABLE IF NOT EXISTS public.gastos (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        tipo_gasto TEXT NOT NULL,
        importe NUMERIC NOT NULL,
        descripcion TEXT,
        nro_comprobante TEXT,
        forma_pago TEXT,
        viaje_id UUID REFERENCES public.viajes(id) ON DELETE CASCADE,
        fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
        chofer_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
        comprobante_url TEXT,
        created_at TIMESTAMPTZ DEFAULT now()
    );

    -- 2. Asegurar que las políticas RLS existan para permitir acceso público a gastos
    ALTER TABLE public.gastos ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Allow all public operations on gastos" ON public.gastos;
    CREATE POLICY "Allow all public operations on gastos" ON public.gastos
    AS PERMISSIVE FOR ALL TO public
    USING (true)
    WITH CHECK (true);

    -- 3. Insertar bucket en storage.buckets si no existe
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES ('gastos', 'gastos', true, null, null)
    ON CONFLICT (id) DO NOTHING;

    -- 4. Políticas para el bucket gastos
    DROP POLICY IF EXISTS "Allow public access to gastos" ON storage.objects;
    CREATE POLICY "Allow public access to gastos" ON storage.objects
    FOR ALL TO public
    USING (bucket_id = 'gastos')
    WITH CHECK (bucket_id = 'gastos');
  ''';

  try {
    final res = await client.rpc('exec_sql', params: {'sql': sql});
    print('Éxito al ejecutar SQL en Supabase! Resultado: $res');
  } catch (e) {
    print('Error al crear tabla/bucket: $e');
  }

  // Verificar si la tabla existe ahora y si se puede hacer select
  try {
    final check = await client.from('gastos').select().limit(0);
    print('Confirmado! La tabla gastos es accesible ahora y tiene 0 o más filas.');
  } catch (e) {
    print('Fallo al comprobar tabla gastos después de crearla: $e');
  }
}
