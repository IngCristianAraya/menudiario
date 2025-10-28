# Guía de Despliegue Multi-Tenant con tubarrio.pe

## Arquitectura de Dominios

### Estructura de Subdominios
- **Host Central**: `menudiario.tubarrio.pe` (login, panel admin, tenant por defecto)
- **Clientes**: `lacabanita.tubarrio.pe`, `menucabanita.tubarrio.pe`, etc.
- **Directorio Principal**: `tubarrio.pe` (mantiene la web actual intacta)

### Flujo de Usuario
1. Cliente visita ficha en `https://www.tubarrio.pe/servicio/la-cabanita`
2. Hace clic en "Hacer Pedido" → redirige a `https://lacabanita.tubarrio.pe`
3. Si no está logueado → redirige a `https://menudiario.tubarrio.pe/auth/login`
4. Después del login → regresa a `https://lacabanita.tubarrio.pe`

## Configuración DNS

### Registros Necesarios
```
# Mantener existentes (NO TOCAR)
tubarrio.pe         A/CNAME    → [servidor actual]
www.tubarrio.pe     CNAME      → [servidor actual]

# Nuevos registros para multi-tenant
*.tubarrio.pe       CNAME      → cname.vercel-dns.com
```

### Verificación DNS
```bash
# Verificar que el wildcard funciona
nslookup menudiario.tubarrio.pe
nslookup lacabanita.tubarrio.pe
```

## Configuración en Vercel

### 1. Dominios del Proyecto
En el proyecto del gestor de pedidos, añadir:
- `*.tubarrio.pe` (wildcard para todos los subdominios)
- **NO añadir** `tubarrio.pe` (ya está en uso por el otro proyecto)

### 2. Variables de Entorno - Producción

```env
# Dominio raíz para construir URLs de subdominios
NEXT_PUBLIC_ROOT_DOMAIN=tubarrio.pe

# Host central para login y autenticación
NEXTAUTH_URL=https://menudiario.tubarrio.pe

# Secreto estable para NextAuth
NEXTAUTH_SECRET=tu_secreto_super_seguro_aqui

# Supabase Producción
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_publica
SUPABASE_SERVICE_ROLE_KEY=tu_clave_privada

# Opcional: Confianza en host para NextAuth v5
AUTH_TRUST_HOST=1
```

### 3. Variables de Entorno - Preview/Development

```env
# Sin dominio raíz para evitar redirecciones en preview
NEXT_PUBLIC_ROOT_DOMAIN=

# URL de preview o localhost
NEXTAUTH_URL=https://tu-preview-url.vercel.app
# o para desarrollo local:
# NEXTAUTH_URL=http://localhost:3000

# Mismo secreto que producción
NEXTAUTH_SECRET=tu_secreto_super_seguro_aqui

# Supabase (puede ser el mismo o uno de desarrollo)
NEXT_PUBLIC_SUPABASE_URL=https://tu-proyecto.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_publica
SUPABASE_SERVICE_ROLE_KEY=tu_clave_privada
```

## Configuración de Tenants en Base de Datos

### Tenant por Defecto (Host Central)
```sql
INSERT INTO tenants (nombre, subdominio, activo) VALUES 
('Menu Diario', 'menudiario', true);
```

### Tenants de Clientes
```sql
INSERT INTO tenants (nombre, subdominio, activo) VALUES 
('La Cabañita', 'lacabanita', true),
('Menu Cabañita', 'menucabanita', true);
```

## Configuración de Sesión Compartida (SSO)

### Opción 1: Sesión Compartida Entre Subdominios
Si quieres que un login sirva para todos los subdominios:

```typescript
// En lib/auth.ts, dentro de authOptions:
cookies: {
  sessionToken: {
    name: 'next-auth.session-token',
    options: {
      domain: '.tubarrio.pe',
      path: '/',
      httpOnly: true,
      sameSite: 'lax',
      secure: true
    }
  },
  callbackUrl: {
    name: 'next-auth.callback-url',
    options: {
      domain: '.tubarrio.pe',
      path: '/',
      httpOnly: true,
      sameSite: 'lax',
      secure: true
    }
  }
}
```

### Opción 2: Sesión Aislada por Tenant
Mantener la configuración actual (sin modificar cookies).

## Integración con Directorio tubarrio.pe

### Enlaces desde Fichas de Servicios
En cada ficha del directorio (ejemplo: `/servicio/la-cabanita`):

```html
<a href="https://lacabanita.tubarrio.pe" 
   class="btn-hacer-pedido">
   🍽️ Hacer Pedido Online
</a>
```

### Botón de Administración
Para que los dueños accedan al panel:

```html
<a href="https://menudiario.tubarrio.pe/admin/dashboard" 
   class="btn-admin">
   ⚙️ Panel de Administración
</a>
```

## Desarrollo Local

### Simulación de Subdominios
```bash
# Añadir al archivo hosts (Windows: C:\Windows\System32\drivers\etc\hosts)
127.0.0.1 menudiario.localhost
127.0.0.1 lacabanita.localhost
127.0.0.1 menucabanita.localhost
```

### URLs de Desarrollo
- Host central: `http://menudiario.localhost:3000`
- Clientes: `http://lacabanita.localhost:3000`

### Variables Locales (.env.local)
```env
NEXT_PUBLIC_ROOT_DOMAIN=
NEXTAUTH_URL=http://localhost:3000
NEXTAUTH_SECRET=desarrollo_secreto_local
```

## Checklist de Despliegue

### Pre-Despliegue
- [ ] DNS wildcard configurado (`*.tubarrio.pe`)
- [ ] Variables de entorno configuradas en Vercel
- [ ] Tenants creados en base de datos
- [ ] Build local exitoso (`npm run build`)

### Post-Despliegue
- [ ] Verificar `https://menudiario.tubarrio.pe` carga correctamente
- [ ] Probar login en host central
- [ ] Verificar redirección a tenant específico
- [ ] Probar `https://lacabanita.tubarrio.pe` (crear tenant de prueba)
- [ ] Verificar que `https://tubarrio.pe` sigue funcionando (no afectado)

### Pruebas de Flujo Completo
1. Visitar `https://www.tubarrio.pe/servicio/la-cabanita`
2. Hacer clic en "Hacer Pedido" → debe ir a `https://lacabanita.tubarrio.pe`
3. Si no está logueado → debe redirigir a `https://menudiario.tubarrio.pe/auth/login`
4. Después del login → debe regresar a `https://lacabanita.tubarrio.pe`
5. Verificar que el tenant correcto se carga (La Cabañita)

## Monitoreo y Mantenimiento

### Logs a Revisar
- Errores de redirección entre subdominios
- Fallos de autenticación cross-domain
- Tenants no encontrados (404s)

### Métricas Importantes
- Tiempo de carga por subdominio
- Tasa de conversión login → pedido
- Errores de SSL en subdominios

## Troubleshooting

### Problema: Redirección infinita
**Causa**: `NEXTAUTH_URL` mal configurado o conflicto de cookies
**Solución**: Verificar que `NEXTAUTH_URL` apunte al host central correcto

### Problema: Tenant no encontrado
**Causa**: Subdominio no existe en base de datos
**Solución**: Crear tenant con el subdominio correcto en tabla `tenants`

### Problema: SSL no funciona en subdominio
**Causa**: Vercel no ha emitido certificado para el wildcard
**Solución**: Esperar propagación DNS (hasta 24h) o contactar soporte Vercel

### Problema: Sesión no persiste entre subdominios
**Causa**: Cookies no configuradas para dominio compartido
**Solución**: Implementar configuración SSO (Opción 1 arriba)

## Contacto y Soporte

Para dudas sobre la implementación:
- Revisar logs en Vercel Dashboard
- Verificar configuración DNS en proveedor
- Comprobar variables de entorno en cada ambiente

## Aislamiento por Cliente: Credenciales y Base de Datos

### Objetivo
Cada cliente tiene:
- Sus propias credenciales de acceso al panel y app (creadas por ti).
- Su propia base de datos aislada de otros clientes.

### Estrategias de Aislamiento
- Opción A (recomendada para aislamiento fuerte): **Un proyecto de Supabase por cliente**.
  - Ventajas: separación total de datos, autenticación y storage; menores riesgos de fuga.
  - Coste: más proyectos que administrar; credenciales por cliente.
- Opción B (simplificada): **Un solo Supabase con RLS por tenant**.
  - Ventajas: gestión centralizada y menor coste operacional.
  - Nota: no cumple el requisito de “su propia base de datos” al 100%.

Para tu requisito explícito de “su propia base de datos”, usaremos la **Opción A**.

### Provisionamiento por Cliente (Supabase por tenant)
1. Crear proyecto de Supabase para el cliente (ej. La Cabañita):
   - Obtener `SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.
2. Añadir variables de entorno en Vercel (Proyecto SaaS) con sufijos por subdominio:
   - `SUPABASE_URL__lacabanita`
   - `SUPABASE_ANON_KEY__lacabanita`
   - `SUPABASE_SERVICE_ROLE__lacabanita`
   - Repetir para `thepoint`, etc.
3. Registrar el tenant en la BD central (tabla `tenants` del proyecto SaaS):
   - `name`, `subdomain` (ej. `lacabanita`), `is_active`.
4. Crear credenciales del administrador del cliente (por ti) en el proyecto Supabase del cliente:
   - Email: `menudiario@cabanita.com`
   - Password: `admincabanita123` (recomendado usar contraseñas fuertes)
5. Asignar rol en la BD (si usas tabla central `tenant_users`):
   - Vincular el `user_id` (del auth del cliente) al `tenant_id` de `lacabanita` con rol `owner`/`admin`.

### Ejemplo de Creación de Usuario Admin (Servidor)
Usa la API Admin de Supabase con la `service_role` del cliente.

```typescript
// app/api/tenants/[subdomain]/create-admin/route.ts
import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

function getTenantSecrets(subdomain: string) {
  const url = process.env[`SUPABASE_URL__${subdomain}`]!
  const serviceRole = process.env[`SUPABASE_SERVICE_ROLE__${subdomain}`]!
  return { url, serviceRole }
}

export async function POST(req: Request, { params }: { params: { subdomain: string } }) {
  const { email, password } = await req.json()
  const { url, serviceRole } = getTenantSecrets(params.subdomain)

  const supabaseAdmin = createClient(url, serviceRole, {
    auth: { autoRefreshToken: false, persistSession: false }
  })

  const { data, error } = await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true
  })

  if (error) return NextResponse.json({ error: error.message }, { status: 400 })
  return NextResponse.json({ user: data.user })
}
```

### Cliente Supabase por Tenant (Runtime)
El frontend y backend deben crear el cliente de Supabase con las credenciales del subdominio actual.

```typescript
// lib/supabase/tenant.ts
import { createClient } from '@supabase/supabase-js'

export function getTenantSupabaseClient(subdomain: string) {
  const url = process.env[`SUPABASE_URL__${subdomain}`]
  const anon = process.env[`SUPABASE_ANON_KEY__${subdomain}`]
  if (!url || !anon) throw new Error(`Credenciales Supabase faltantes para ${subdomain}`)
  return createClient(url, anon)
}

export function getTenantSupabaseAdmin(subdomain: string) {
  const url = process.env[`SUPABASE_URL__${subdomain}`]
  const serviceRole = process.env[`SUPABASE_SERVICE_ROLE__${subdomain}`]
  if (!url || !serviceRole) throw new Error(`Service role faltante para ${subdomain}`)
  return createClient(url, serviceRole, { auth: { autoRefreshToken: false, persistSession: false } })
}
```

Uso sugerido:
- En `middleware`/SSR, detectar `subdomain` y exponerlo vía headers/cookies.
- En `Providers`, inicializar el cliente con `getTenantSupabaseClient(subdomain)`.
- En rutas API, usar `getTenantSupabaseAdmin(subdomain)` para operaciones privilegiadas.

### Seguridad y Buenas Prácticas
- No almacenar `service_role` en la BD central ni en el cliente; sólo en variables de entorno.
- Contraseñas: usar contraseñas largas y aleatorias; forzar cambio en primer login.
- Auditar accesos admin: registrar quién crea/edita credenciales.
- SSL activo en todos los subdominios; CORS y RLS estrictos.

### Flujo para Crear un Nuevo Cliente
1. Crear proyecto Supabase del cliente y copiar credenciales.
2. Añadir variables `SUPABASE_*__subdominio` en Vercel (Producción).
3. Crear registro en `tenants` (nombre + subdominio).
4. Crear usuario admin del cliente con la API Admin (como tú lo harás).
5. Probar login en `https://<subdominio>.tubarrio.pe/auth/login` y acceso al panel.

### Nota sobre `lacabanita.tubarrio.pe`
Si ves `DEPLOYMENT_NOT_FOUND` o 404:
- Asegúrate de tener el wildcard DNS `*.tubarrio.pe → cname.vercel-dns.com`.
- Añade `*.tubarrio.pe` al proyecto correcto en Vercel (gestor de pedidos).
- Despliega y espera la emisión del certificado SSL (puede tardar hasta 24h).