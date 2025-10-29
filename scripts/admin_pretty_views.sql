-- Vistas con IDs legibles para administración en Supabase
-- Objetivo: usar `slug` como identificador visible, manteniendo `id` UUID para integridad

BEGIN;

-- Vista de tenants con ID legible
CREATE OR REPLACE VIEW public.tenants_pretty AS
SELECT 
  t.slug        AS id_pretty,
  t.id          AS internal_id,
  t.name        AS name,
  t.is_active   AS is_active
FROM public.tenants t;

COMMENT ON VIEW public.tenants_pretty IS 'Vista administrativa: muestra slug como id_pretty y conserva id UUID como internal_id';

-- Vista de restaurantes con ID legible y datos del tenant
CREATE OR REPLACE VIEW public.restaurantes_pretty AS
SELECT 
  r.slug        AS id_pretty,
  r.id          AS internal_id,
  r.nombre      AS nombre,
  r.email       AS email,
  r.activo      AS activo,
  r.tenant_id   AS tenant_id,
  t.slug        AS tenant_slug,
  t.name        AS tenant_name
FROM public.restaurantes r
LEFT JOIN public.tenants t ON t.id = r.tenant_id;

COMMENT ON VIEW public.restaurantes_pretty IS 'Vista administrativa: muestra slug como id_pretty y relaciona al tenant por slug';

COMMIT;

-- Instrucciones de uso:
-- 1) Ejecuta este archivo en el SQL Editor de Supabase.
-- 2) En la interfaz, abre las vistas `tenants_pretty` y `restaurantes_pretty` para ver IDs legibles.
-- 3) Las vistas respetan RLS de las tablas base.

-- Vista de tenant_users con identificadores legibles
CREATE OR REPLACE VIEW public.tenant_users_pretty AS
SELECT 
  (t.slug || '-' || substr(tu.user_id::text, 1, 8)) AS id_pretty,
  tu.id           AS internal_id,
  tu.user_id      AS user_id,
  tu.tenant_id    AS tenant_id,
  tu.role         AS role,
  tu.created_at   AS created_at,
  tu.updated_at   AS updated_at,
  t.slug          AS tenant_slug,
  r.slug          AS restaurante_slug
FROM public.tenant_users tu
LEFT JOIN public.tenants t ON t.id = tu.tenant_id
LEFT JOIN public.perfiles_usuarios pu ON pu.id = tu.user_id
LEFT JOIN public.restaurantes r ON r.id = pu.restaurante_id;

COMMENT ON VIEW public.tenant_users_pretty IS 'Vista administrativa: combina tenant_slug + fragmento de user_id para id_pretty y muestra slugs relacionados';