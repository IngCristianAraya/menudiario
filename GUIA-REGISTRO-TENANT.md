# Guía Rápida: Registrar un nuevo Tenant (Subdominio)

Objetivo: activar un subdominio (tenant) como `lacabanita.tubarrio.pe` en la app de pedidos usando un solo código y múltiples proyectos de Supabase.

## Requisitos (una sola vez)
- DNS: `*.tubarrio.pe` apuntando a `cname.vercel-dns.com` (CNAME wildcard) en tu proveedor.
- Vercel: `tubarrio.pe` agregado como dominio de Producción en el proyecto.
- Entorno global (Production):
  - `NEXT_PUBLIC_ROOT_DOMAIN` = `tubarrio.pe`
  - `NEXT_PUBLIC_SUPABASE_URL` = URL del Supabase “central” (SaaS core).
  - `SUPABASE_SERVICE_ROLE_KEY` = service_role del Supabase “central”.

## Datos que necesitas por cada tenant
- Subdominio: `lacabanita`
- Nombre visible: `La Cabañita`
- Identificador del restaurante en Supabase (uuid): `restaurante_id`

Nota: En el modo de “un solo proyecto Supabase con RLS”, no se requieren credenciales por tenant. La aplicación usa sólo `SUPABASE_URL`, `SUPABASE_ANON_KEY` y `SUPABASE_SERVICE_ROLE` globales del proyecto.

Si operas en el modo “un proyecto por tenant”, entonces sí necesitas credenciales por cliente:
- `SUPABASE_URL__lacabanita`
- `SUPABASE_ANON_KEY__lacabanita`
- `SUPABASE_SERVICE_ROLE__lacabanita`

---

## Opción A (rápida): Manual en Vercel + crear admin por API
1) Registrar tenant en BD central (tabla `tenants`)
- En el Supabase central, inserta:
```json
{
  "subdominio": "lacabanita",
  "nombre": "La Cabañita",
  "activo": true
}
```

2) Agregar variables del tenant en Vercel (Production)
- `SUPABASE_URL__lacabanita`
- `SUPABASE_ANON_KEY__lacabanita`
- `SUPABASE_SERVICE_ROLE__lacabanita`

3) Crear usuario admin del tenant
- PowerShell:
```powershell
$headers = @{ "x-client-service-role" = "<SUPABASE_SERVICE_ROLE__lacabanita>"; "Content-Type" = "application/json" }
$body = @{ email = "admin@lacabanita.com"; password = "TuPasswordFuerte123" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "https://lacabanita.tubarrio.pe/api/tenants/lacabanita/create-admin" -Headers $headers -Body $body
```

4) Probar login
- Ir a `https://lacabanita.tubarrio.pe/auth/login` y entrar con el admin creado.

---

## Opción B (automática): Script PowerShell
Este proyecto incluye `scripts/register-tenant.ps1` para automatizar los pasos.

### 1) Preparar variables globales en tu sesión (solo si no están ya en el entorno)
```powershell
$env:NEXT_PUBLIC_ROOT_DOMAIN = "tubarrio.pe"
$env:NEXT_PUBLIC_SUPABASE_URL = "https://<TU_SUPABASE_CENTRAL>.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "<SERVICE_ROLE_CENTRAL>"

# Opcional (para crear env vars en Vercel automáticamente):
$env:VERCEL_TOKEN = "<TOKEN_PERSONAL_VERCEL>"
$env:VERCEL_PROJECT_ID = "<ID_DEL_PROYECTO_EN_VERCEL>"
```

### 2) Ejecutar el registro del tenant
```powershell
./scripts/register-tenant.ps1 \
  -Subdomain "lacabanita" \
  -Name "La Cabañita" \
  -TenantSupabaseUrl "https://<SUPABASE_DEL_CLIENTE>.supabase.co" \
  -TenantSupabaseAnonKey "<ANON_KEY_DEL_CLIENTE>" \
  -TenantSupabaseServiceRoleKey "<SERVICE_ROLE_DEL_CLIENTE>" \
  -AdminEmail "admin@lacabanita.com" \
  -AdminPassword "TuPasswordFuerte123"
```

El script:
- Inserta el tenant en la BD central.
- Crea las 3 env vars del tenant en Vercel si defines `VERCEL_TOKEN` y `VERCEL_PROJECT_ID`.
- Crea el usuario admin llamando al endpoint del tenant.

### 3) Verificación rápida
- `https://lacabanita.tubarrio.pe/api/tenant/config` → debe devolver `{ subdomain, url, anonKey }` del tenant.
- `https://lacabanita.tubarrio.pe/auth/login` → login con el admin creado.

---

## Notas útiles
- Si ves `TenantNotFound`, faltan: registro en `tenants` o las env vars del tenant en Vercel.
- Puedes validar varios tenants apuntando al mismo Supabase (poniendo mismas env vars en distintos `SUPABASE_*__subdominio`). Útil para pruebas, no recomendado en producción.
- No necesitas nuevos despliegues separados; es un solo código para todos los tenants. Al guardar env vars, Vercel hace redeploy automático y aplica para todos.

## Ejemplos de uso (copiar/pegar)
- Registrar `lacabanita` y crear admin (automático):
```powershell
./scripts/register-tenant.ps1 -Subdomain "lacabanita" -Name "La Cabañita" \
  -TenantSupabaseUrl "https://ABC.supabase.co" -TenantSupabaseAnonKey "ANON..." -TenantSupabaseServiceRoleKey "SR..." \
  -AdminEmail "admin@lacabanita.com" -AdminPassword "C0ntra$eñaFuerte!"
```

- Solo registrar y configurar env vars (sin admin):
```powershell
./scripts/register-tenant.ps1 -Subdomain "thepoint" -Name "The Point" \
  -TenantSupabaseUrl "https://XYZ.supabase.co" -TenantSupabaseAnonKey "ANON..." -TenantSupabaseServiceRoleKey "SR..."
```

---

## Problemas comunes
- `DEPLOYMENT_NOT_FOUND` en Vercel: refresca el dominio y espera propagación DNS.
- Error creando admin: verifica que el subdominio resuelve y que pusiste `x-client-service-role` correcto.
- `Config Supabase no disponible`: faltan env vars globales de fallback o las del tenant.
## Registro rápido: La sazón criolla

Usa el SQL listo en `scripts/seed_tenant_lasazoncriolla.sql` en el SQL Editor de Supabase.

Versión directa (columnas en inglés):

```sql
INSERT INTO public.tenants (name, subdomain, config, is_active)
VALUES ('La sazón criolla', 'lasazoncriollamenu', '{}'::jsonb, true)
ON CONFLICT (subdomain) DO UPDATE
  SET name = EXCLUDED.name,
      is_active = EXCLUDED.is_active;

UPDATE public.restaurantes
SET tenant_id = (SELECT id FROM public.tenants WHERE subdomain = 'lasazoncriollamenu')
WHERE slug = 'lasazoncriolla' OR nombre = 'La sazón criolla';

-- (Opcional) crea relación admin si existe el usuario en auth.users
INSERT INTO public.tenant_users (user_id, tenant_id, role)
SELECT u.id, t.id, 'admin'
FROM auth.users u
JOIN public.tenants t ON t.subdomain = 'lasazoncriollamenu'
WHERE lower(u.email) = lower('admin@lasazoncriolla.com')
ON CONFLICT DO NOTHING;
```

Verificaciones:

```sql
SELECT id, name, subdomain, is_active FROM public.tenants
WHERE subdomain = 'lasazoncriollamenu';

SELECT id, nombre, slug, tenant_id FROM public.restaurantes
WHERE slug = 'lasazoncriolla' OR nombre = 'La sazón criolla';

SELECT tenant_id, user_id, role FROM public.tenant_users
WHERE tenant_id = (SELECT id FROM public.tenants WHERE subdomain = 'lasazoncriollamenu');
```

Visualización local:
- Abre `http://lasazoncriollamenu.lvh.me:3001` (server dev activo).
- `lvh.me` permite subdominios locales hacia `127.0.0.1`.