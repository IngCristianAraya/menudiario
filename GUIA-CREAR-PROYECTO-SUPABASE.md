# Guía Rápida: Crear un proyecto de Supabase por tenant

Objetivo: tener un proyecto de Supabase independiente para cada cliente/subdominio y enlazarlo con la app multi-tenant en Vercel.

## Antes de empezar
- Tu app ya está desplegada en Vercel con `tubarrio.pe`.
- DNS wildcard `*.tubarrio.pe` apunta a `cname.vercel-dns.com`.
- Tienes un Supabase “central” (SaaS core) donde está la tabla `tenants`.

## Paso a paso (por cada tenant)
1) Crear proyecto en Supabase
- Dashboard → `New project` → elige organización → `Project name` (ej. `lacabanita-prod`).
- Region: cercana a tus usuarios.
- Setea la `Database password` (guárdala bien).
- Crear proyecto y esperar a que se provisionen los servicios.

2) Obtener credenciales del proyecto
- Project Settings → `API`.
- Copia:
  - `Project URL` (ej. `https://xxxx.supabase.co`).
  - `anon key` (cliente/SDK).
  - `service_role key` (backend/administración).

3) Crear el esquema de datos del tenant (SQL)
- Abre `SQL Editor` en el proyecto recién creado.
- Pega y ejecuta los scripts necesarios para el sistema de pedidos. Puedes usar los archivos del repo:
  - `supabase/migrations/20231026_create_pedidos_tables.sql`
  - `supabase/migrations/20251008050454_create_pedidos_system.sql`
- Si un script crea tablas de `tenants`, sáltalo en proyectos de cliente (esa tabla es solo del Supabase central).
- Verifica tablas clave: `pedidos`, `items_pedido`, `platos`, `perfiles_usuarios`, `restaurantes`.

4) Configurar variables en Vercel (Production)
- En el proyecto de Vercel (el central), agrega:
  - `SUPABASE_URL__<subdominio>` → URL del Supabase del cliente.
  - `SUPABASE_ANON_KEY__<subdominio>` → anon key del cliente.
  - `SUPABASE_SERVICE_ROLE__<subdominio>` → service_role del cliente.
- Guardar; Vercel redeploya automáticamente.

5) Registrar el tenant en el Supabase central
- Inserta en la tabla `tenants`:
```json
{
  "subdominio": "lacabanita",
  "nombre": "La Cabañita",
  "activo": true,
  "configuracion": { "ticketera_enabled": false }
}
```
- Opcional: usa el script `scripts/register-tenant.ps1` para automatizar (inserta tenant, crea env vars y admin).

6) Crear usuario admin del tenant
- Opción A (API):
```powershell
$headers = @{ "x-client-service-role" = "<SUPABASE_SERVICE_ROLE__lacabanita>"; "Content-Type" = "application/json" }
$body = @{ email = "admin@lacabanita.com"; password = "C0ntra$eñaFuerte!" } | ConvertTo-Json
Invoke-RestMethod -Method Post -Uri "https://lacabanita.tubarrio.pe/api/tenants/lacabanita/create-admin" -Headers $headers -Body $body
```
- Opción B (Dashboard): Settings → Authentication → Add user (con password).

7) Verificación
- `https://lacabanita.tubarrio.pe/api/tenant/config` debe mostrar `{ subdomain, url, anonKey }` del tenant.
- `https://lacabanita.tubarrio.pe/auth/login` debe permitir login con el admin creado.

## Cuenta y planes (resumen)
- Puedes crear varios proyectos con una sola cuenta.
- Plan gratuito: hasta 2 proyectos activos por organización; proyectos inactivos se pausan tras 1 semana [2][4].
- Si necesitas más proyectos: crea otra organización o pasa proyectos a Pro.
- Pro plan: pago por proyecto con cuotas mayores y sin pausar por inactividad (ver detalles en Pricing).

## Diseño de datos optimizado para “platos diarios”
- Evita duplicar 150 platos por día. Usa tres tablas:
  - `platos` (catálogo del tenant): id, nombre, precio_base, categoría, activo.
  - `menus_dia` (cabecera): id, fecha, estado.
  - `menus_dia_platos` (detalle): menu_id, plato_id, precio_del_dia, disponible.
- Flujo:
  - El admin mantiene su catálogo en `platos`.
  - Cada día selecciona qué platos van y opcionalmente ajusta precio del día en `menus_dia_platos`.
  - Los pedidos referencian `menus_dia_platos` para garantizar consistencia del precio del día.
- Ventaja: poco almacenamiento, consultas simples, sin imágenes el costo es mínimo.

## Estrategia de costos
- Inicio: puedes usar un solo Supabase para varios tenants (poniendo las mismas credenciales en varias `SUPABASE_*__<subdominio>`). Úsalo solo para validar; cuando un cliente crezca, migra a su propio Supabase.
- Migración: exporta los datos del tenant con `pg_dump`/`COPY`, crea proyecto nuevo, importa y actualiza las env vars en Vercel.

## Problemas comunes
- `TenantNotFound`: falta registro en `tenants` o las env vars del subdominio.
- No aparece config del tenant: revisa `GET /api/tenant/config`; si dice `fallback`, faltan env vars por subdominio.
- Error creando admin: valida DNS y el header `x-client-service-role` correcto.

[2]: https://supabase.com/pricing
[4]: https://supabase.com/docs/guides/platform/billing-on-supabase