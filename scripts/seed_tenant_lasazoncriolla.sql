-- Seed de Tenant: La sazón criolla
-- Ajusta valores según corresponda antes de ejecutar en el SQL Editor de Supabase.

-- 1) Crear/actualizar tenant con columnas en inglés (esquema actual)
INSERT INTO public.tenants (name, subdomain, config, is_active)
VALUES ('La sazón criolla', 'lasazoncriollamenu', '{}'::jsonb, true)
ON CONFLICT (subdomain) DO UPDATE
  SET name = EXCLUDED.name,
      is_active = EXCLUDED.is_active;

-- 2) Vincular restaurante al tenant por slug o por nombre
UPDATE public.restaurantes
SET tenant_id = (SELECT id FROM public.tenants WHERE subdomain = 'lasazoncriollamenu')
WHERE slug = 'lasazoncriolla' OR nombre = 'La sazón criolla';

-- 3) (Opcional) Vincular usuario admin al tenant si existe en auth.users
-- Reemplaza el email si difiere
INSERT INTO public.tenant_users (user_id, tenant_id, role)
SELECT u.id, t.id, 'admin'
FROM auth.users u
JOIN public.tenants t ON t.subdomain = 'lasazoncriollamenu'
WHERE lower(u.email) = lower('admin@lasazoncriolla.com')
ON CONFLICT DO NOTHING;

-- 4) Verificaciones
-- Tenant creado
SELECT id, name, subdomain, is_active FROM public.tenants
WHERE subdomain = 'lasazoncriollamenu';

-- Restaurante vinculado
SELECT id, nombre, slug, tenant_id FROM public.restaurantes
WHERE slug = 'lasazoncriolla' OR nombre = 'La sazón criolla';

-- Usuarios del tenant (si se creó la relación)
SELECT tenant_id, user_id, role FROM public.tenant_users
WHERE tenant_id = (SELECT id FROM public.tenants WHERE subdomain = 'lasazoncriollamenu');