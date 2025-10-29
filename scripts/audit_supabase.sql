/*
  Supabase Audit – Inventario de esquema, RLS y uso

  Ejecuta este archivo en el SQL Editor de Supabase.
  Objetivo: ver qué tablas existen, cuáles están vacías, qué políticas RLS hay,
  y cómo se relacionan con tenants/restaurantes.
*/

-- 1) Inventario de tablas en schema public: RLS y políticas
SELECT 
  t.tablename AS table_name,
  t.rowsecurity AS rls_enabled,
  COALESCE(p.policy_count, 0) AS policy_count,
  c.reltuples::bigint AS row_estimate
FROM pg_tables t
JOIN pg_class c 
  ON c.relname = t.tablename 
 AND c.relnamespace = 'public'::regnamespace
LEFT JOIN (
  SELECT schemaname, tablename, COUNT(*) AS policy_count
  FROM pg_policies
  WHERE schemaname = 'public'
  GROUP BY schemaname, tablename
) p 
  ON p.tablename = t.tablename
WHERE t.schemaname = 'public'
ORDER BY row_estimate DESC NULLS LAST, table_name;

-- 2) Conteo aproximado por tabla (sin errores si faltan tablas)
SELECT relname AS table_name, n_live_tup AS approx_rows
FROM pg_stat_user_tables
ORDER BY approx_rows DESC, relname;

-- 3) Políticas RLS detalladas
SELECT schemaname, tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 4) Tablas con columna tenant_id (multi-tenant legacy)
SELECT table_name
FROM information_schema.columns
WHERE table_schema = 'public' AND column_name = 'tenant_id'
ORDER BY table_name;

-- 5) Columnas de tenants y restaurantes (para ver compatibilidad slug/subdomain)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'tenants'
ORDER BY ordinal_position;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'restaurantes'
ORDER BY ordinal_position;

-- 6) Muestra rápida de filas clave (si existen)
-- Nota: algunas instancias usan 'slug' y no tienen 'subdomain'.
-- Usamos la variable de fila completa y convertimos a JSONB para leer
-- ambas claves de forma segura (las que no existan devolverán NULL).
SELECT 
  t.id,
  t.name,
  to_jsonb(t) ->> 'subdomain' AS subdomain,
  to_jsonb(t) ->> 'slug' AS slug,
  t.contact_email,
  t.is_active
FROM public.tenants AS t
ORDER BY t.name NULLS LAST
LIMIT 20;

SELECT id, nombre, slug, tenant_id
FROM public.restaurantes
ORDER BY created_at DESC NULLS LAST
LIMIT 20;

-- 7) Claves foráneas que referencian tenants/restaurantes
SELECT conname,
       conrelid::regclass AS table_name,
       confrelid::regclass AS referenced_table,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE contype = 'f'
  AND connamespace = 'public'::regnamespace
  AND (confrelid::regclass::text = 'public.tenants' 
    OR confrelid::regclass::text = 'public.restaurantes')
ORDER BY table_name;

-- 8) Vistas en public
SELECT table_name AS view_name, view_definition
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY view_name;

-- 9) Funciones relevantes para multi-tenant
SELECT n.nspname AS schema, p.proname AS function, pg_get_functiondef(p.oid) AS definition
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN ('get_tenant_by_subdomain', 'check_user_tenant_access')
ORDER BY p.proname;

-- 10) Estado de RLS por tabla
SELECT schemaname, tablename, rowsecurity AS rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;

/*
  Interpretación rápida:
  - Si una tabla aparece con approx_rows = 0 y policy_count = 0, probablemente no se usa.
  - Si existen ambas familias de tablas (legacy: perfiles_usuarios/pedidos/items_pedido/platos/restaurantes y nuevas: profiles/orders/order_items/products), decide cuál está en uso según el código.
  - Verifica que las tablas activas tengan RLS (rls_enabled = true) y políticas adecuadas.
*/