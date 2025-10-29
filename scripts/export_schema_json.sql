/*
  Exporta esquema y RLS a un JSON consolidado.
  Ejecuta este archivo en el SQL Editor de Supabase y copia/descarga el resultado.
*/

WITH tables AS (
  SELECT t.tablename AS table_name,
         t.rowsecurity AS rls_enabled,
         c.reltuples::bigint AS row_estimate
  FROM pg_tables t
  JOIN pg_class c 
    ON c.relname = t.tablename 
   AND c.relnamespace = 'public'::regnamespace
  WHERE t.schemaname = 'public'
),
columns AS (
  SELECT table_name,
         jsonb_agg(
           jsonb_build_object(
             'column_name', column_name,
             'data_type', data_type,
             'is_nullable', is_nullable,
             'column_default', column_default
           )
           ORDER BY ordinal_position
         ) AS cols
  FROM information_schema.columns
  WHERE table_schema = 'public'
  GROUP BY table_name
),
constraints AS (
  SELECT conrelid::regclass::text AS table_name,
         jsonb_agg(
           jsonb_build_object(
             'name', conname,
             'type', contype,
             'definition', pg_get_constraintdef(oid)
           )
           ORDER BY conname
         ) AS cons
  FROM pg_constraint
  WHERE connamespace = 'public'::regnamespace
  GROUP BY conrelid
),
indexes AS (
  SELECT tablename AS table_name,
         jsonb_agg(
           jsonb_build_object(
             'name', indexname,
             'definition', indexdef
           )
           ORDER BY indexname
         ) AS idxs
  FROM pg_indexes
  WHERE schemaname = 'public'
  GROUP BY tablename
),
policies AS (
  SELECT tablename AS table_name,
         jsonb_agg(
           jsonb_build_object(
             'policyname', policyname,
             'cmd', cmd,
             'qual', qual,
             'with_check', with_check
           )
           ORDER BY policyname
         ) AS pols
  FROM pg_policies
  WHERE schemaname = 'public'
  GROUP BY tablename
),
views AS (
  SELECT table_name AS view_name,
         jsonb_build_object('name', table_name, 'definition', view_definition) AS view_obj
  FROM information_schema.views
  WHERE table_schema = 'public'
),
functions AS (
  SELECT jsonb_agg(
           jsonb_build_object(
             'schema', n.nspname,
             'name', p.proname,
             'definition', pg_get_functiondef(p.oid)
           )
           ORDER BY p.proname
         ) AS funcs
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
),
samples AS (
  SELECT jsonb_build_object(
    'tenants', (
      SELECT jsonb_agg(to_jsonb(s))
      FROM (
        SELECT t.id,
               t.name,
               to_jsonb(t) ->> 'subdomain' AS subdomain,
               to_jsonb(t) ->> 'slug' AS slug,
               t.contact_email,
               t.is_active
        FROM public.tenants t
        ORDER BY t.name NULLS LAST
        LIMIT 10
      ) s
    ),
    'restaurantes', (
      SELECT jsonb_agg(to_jsonb(r))
      FROM (
        SELECT id, nombre, slug, tenant_id, created_at
        FROM public.restaurantes
        ORDER BY created_at DESC NULLS LAST
        LIMIT 10
      ) r
    )
  ) AS samples_obj
)
SELECT jsonb_build_object(
  'generated_at', now(),
  'tables', (
    SELECT jsonb_agg(
      jsonb_build_object(
        'table_name', t.table_name,
        'rls_enabled', t.rls_enabled,
        'row_estimate', t.row_estimate,
        'columns', COALESCE(c.cols, '[]'::jsonb),
        'constraints', COALESCE(cons.cons, '[]'::jsonb),
        'indexes', COALESCE(idx.idxs, '[]'::jsonb),
        'policies', COALESCE(pol.pols, '[]'::jsonb)
      )
      ORDER BY t.table_name
    )
    FROM tables t
    LEFT JOIN columns c ON c.table_name = t.table_name
    LEFT JOIN constraints cons ON cons.table_name = t.table_name
    LEFT JOIN indexes idx ON idx.table_name = t.table_name
    LEFT JOIN policies pol ON pol.table_name = t.table_name
  ),
  'views', (
    SELECT jsonb_agg(view_obj ORDER BY (view_obj->>'name'))
    FROM views
  ),
  'functions', (
    SELECT funcs FROM functions
  ),
  'samples', (
    SELECT samples_obj FROM samples
  )
) AS schema_json;