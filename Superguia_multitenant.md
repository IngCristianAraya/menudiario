# Guía del Proyecto: Sistema Multi-tenant de Gestión de Pedidos

## 📌 Visión General
Sistema de gestión de pedidos con panel de administración multi-tenant, donde cada restaurante (tenant) tiene su propio espacio aislado con sus propios datos, menús, pedidos y configuraciones.

## 🏗️ Arquitectura

### Frontend
- **Framework**: Next.js 13+ (App Router)
- **Estilos**: Tailwind CSS
- **Autenticación**: NextAuth.js con proveedores Google y Email/Contraseña
- **Base de Datos**: Supabase (PostgreSQL)
- **UI Components**: shadcn/ui

### Backend
- **API Routes**: Next.js API Routes
- **Autenticación**: JWT con Supabase Auth
- **Almacenamiento**: Supabase Storage

### Base de Datos (Supabase)
- **Tablas Principales**:
  - `tenants` - Información de cada restaurante
  - `users` - Usuarios del sistema
  - `tenant_users` - Relación usuarios-tenant con roles
  - `menus` - Menús de cada restaurante
  - `categories` - Categorías de productos
  - `products` - Productos de los menús
  - `orders` - Pedidos de los clientes
  - `order_items` - Ítems de cada pedido

## 🔐 Autenticación y Autorización

### Flujo de Autenticación
1. Usuario inicia sesión con Google o Email/Contraseña
2. Se verifica el usuario en Supabase Auth
3. Se crea/actualiza el perfil en la base de datos
4. Se establece la sesión con JWT

### Roles
- **Super Admin**: Acceso completo a todo el sistema
- **Admin de Tenant**: Gestión de su propio restaurante
- **Staff**: Manejo de pedidos y menús
- **Cliente**: Realizar pedidos

## 🏢 Multi-tenancy

### Estrategia de Aislamiento
- **Esquema por Tenant**: Cada restaurante tiene su propio esquema en la base de datos
- **Row-level Security (RLS)**: Políticas para aislar datos entre tenants
- **Middleware**: Verificación de tenant en cada solicitud

### Configuración en Supabase
1. Habilitar RLS en todas las tablas
2. Crear políticas para cada rol y operación
3. Configurar almacenamiento para imágenes de menú

## 🚀 Implementación

### Configuración Inicial
1. Variables de entorno necesarias:
```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=your-supabase-url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# NextAuth
NEXTAUTH_SECRET=your-secret
NEXTAUTH_URL=http://localhost:3000

# Google OAuth
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
```

### Estructura de Carpetas
```
app/
  (auth)/
    login/
    register/
    error/
  (admin)/
    dashboard/
    menus/
    orders/
    settings/
  api/
    auth/
      [...nextauth]/
    menus/
    orders/
    tenants/
```

## 🔄 Flujos Principales

### Registro de Nuevo Restaurante
1. Usuario completa formulario de registro
2. Se crea nuevo tenant en la base de datos
3. Se asigna al usuario como administrador del tenant
4. Se crea esquema inicial para el nuevo restaurante

### Proceso de Pedido
1. Cliente navega por el menú
2. Agrega ítems al carrito
3. Realiza el pedido
4. Notificación en tiempo real al restaurante
5. Seguimiento del estado del pedido

## 🛠️ Configuración Requerida en Supabase

### Políticas RLS Ejemplo
```sql
-- Ejemplo de política para acceder solo a los pedidos del tenant actual
CREATE POLICY "Usuarios pueden ver solo sus pedidos"
ON orders
FOR SELECT
USING (
  tenant_id = (SELECT current_setting('app.current_tenant_id', true)::uuid)
);
```

### Funciones SQL Útiles
```sql
-- Obtener tenant actual
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
  RETURN current_setting('app.current_tenant_id', true)::uuid;
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'No se pudo determinar el tenant actual';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

## 📱 Mobile App (Futuro)
- App nativa con React Native
- Sincronización offline
- Notificaciones push
- Escaneo de códigos QR para pagos

## 🔄 CI/CD
- GitHub Actions para despliegues automáticos
- Entornos separados para desarrollo, staging y producción
- Migraciones de base de datos automatizadas

## 📊 Métricas y Monitoreo
- Logs de errores con Sentry
- Métricas de rendimiento
- Análisis de uso

## 🔒 Seguridad
- Todas las conexiones sobre HTTPS
- CORS estrictamente configurado
- Rate limiting en APIs públicas
- Auditoría de cambios sensibles

## 📅 Próximos Pasos
1. [ ] Implementar panel de administración
2. [ ] Configurar autenticación multi-tenant
3. [ ] Desarrollar gestión de menús
4. [ ] Implementar sistema de pedidos en tiempo real
5. [ ] Crear paneles de análisis
6. [ ] Desarrollar app móvil

## 📚 Recursos
- [Documentación de Supabase](https://supabase.com/docs)
- [Next.js Documentation](https://nextjs.org/docs)
- [NextAuth.js Documentation](https://next-auth.js.org/)

## 🤝 Contribución
1. Hacer fork del repositorio
2. Crear una rama para la funcionalidad
3. Hacer commit de los cambios
4. Hacer push a la rama
5. Abrir un Pull Request

## 📝 Licencia
Este proyecto está bajo la licencia MIT.

# Estado actual y Roadmap (Multi-tenant)

## Qué está funcionando
- Login con `email/contraseña` vía NextAuth usando Supabase Auth (`lib/auth.ts`, `/auth/login`).
- Middleware multi-tenant: resolución de subdominio, headers `x-tenant-*` y verificación opcional de acceso por `check_user_tenant_access` con fallback en localhost (`middleware.ts`).
- Panel Admin básico: layout con protección de sesión, sidebar y dashboard con datos mock (`app/admin/layout.tsx`, `app/admin/dashboard/page.tsx`).
- Endpoints de desarrollo disponibles: `api/dev/test-login`, `api/dev/test-connection` (diagnóstico). `seed-user` existe pero depende del `service_role` y del estado de migraciones.

## Navegación y Roles (SaaS)

### Visión simple
- App de Pedidos (móvil): `/', '/nuevo-pedido', '/pedidos-hoy'` con barra inferior (`BottomNav`).
- Panel Admin: `/admin/dashboard` protegido por sesión y rol.
- Post‑login inteligente:
  - Si hay `callbackUrl` (venías de una ruta protegida del admin), vuelve allí.
  - Si no hay, destinos por rol: `admin/owner` → `/admin/dashboard`; otros → `/`.

### Roles típicos
- `owner`/`admin`: gestión completa del negocio en el panel.
- `cashier`/`waiter`: uso diario de la App de Pedidos.

### Múltiples dispositivos
- Varios mozos/cajeros pueden usar la App de Pedidos a la vez.
- Estados de pedido claros evitan choques: `pendiente`, `preparando`, `listo`, `entregado`.
- Opcional: asignar pedidos a un usuario para ver quién los está atendiendo.

## Implementación actual (v0)
- Raíz pública: se retiró la redirección forzada a `/admin/dashboard` en `middleware.ts`.
- Login por defecto a `/`: se cambió el `callbackUrl` de `'/admin/dashboard'` a `'/'` en `/auth/login`.
- Protección por rol en Admin:
  - `app/admin/layout.tsx` verifica el header `x-user-role` (inyectado por `middleware.ts`).
  - Permite acceso si el rol es `admin` u `owner`. Si el header no existe (desarrollo), no bloquea.
- Botón “Admin” condicional:
  - `BottomNav` muestra enlace a `/admin/dashboard` si el usuario es `admin/owner` o si está activado por configuración.
  - Detección de rol en cliente con `getSession()` de NextAuth (sin `SessionProvider`).
  - Flags de activación:
    - `NEXT_PUBLIC_SHOW_ADMIN_CTA=true` (visibilidad global aunque no haya sesión).
    - `localStorage.showAdminCTA = 'true'` (útil para demos). Si el usuario inicia sesión y NO es `admin/owner`, el botón se oculta.
  - Flujo:
    - Sin sesión: si el flag está activo, el botón se muestra; al pulsar, el middleware exige login y vuelve al admin.
    - Con sesión `staff`: el botón no se muestra.
    - Con sesión `admin/owner`: el botón se muestra.

## Configuración por tenant (plan)
- Tabla `tenant_config` (JSON) para evitar cambios de código por cliente:
  - `branding` (logo, colores), `home_route`, `show_admin_cta`, `require_login_for_staff`.
  - `features` (kiosk_mode, mesa_tracking, delivery_integration, payments).
- UI de configuración en `/admin/configuracion` para editar estos valores.
- La app lee `tenant_config` en runtime y ajusta UI y comportamiento.

## Próximos pasos
- [x] Mantener raíz pública y ajustar post‑login.
- [x] Añadir verificación de rol en layout admin con `x-user-role`.
- [x] Habilitar botón “Admin” condicional en `BottomNav` (env/localStorage).
- [ ] Implementar `tenant_config` y lectura en cliente.
- [ ] Chequeo real de rol desde `tenant_users` y propagación a headers.
- [ ] Decidir si `/nuevo-pedido` y `/pedidos-hoy` requieren login por `tenant_config.require_login_for_staff`.
- Migraciones multi-tenant definidas: tablas `tenants`, `profiles`, `tenant_users`, `products`, `orders`, `order_items` y funciones RPC `get_tenant_by_subdomain`, `check_user_tenant_access` (`supabase/migrations/*`).

## Qué falta o está inconsistente
- Datos iniciales: falta crear un `tenant` de demo y asignar usuarios en `tenant_users`; en local el middleware cae al fallback sin verificación real.
 - Autorización real: el layout admin usa `x-user-role` desde middleware; falta validar rol/tenant desde BD en middleware y ajustar el fallback local.
- Registro: `app/api/auth/register` inserta columnas inexistentes en `profiles` (`email`, `full_name`) y no crea relación en `tenant_users`.
- APIs de pedidos: usan tablas legacy (`perfiles_usuarios`, `pedidos`, `items_pedido`, `platos`) en lugar de `profiles`, `orders`, `order_items`, `products` y sus RLS.
- Vistas admin adicionales (restaurantes, usuarios, productos, configuración) aún no implementadas.
- RLS: existen políticas para tablas nuevas, pero hay que revisar/ajustar operaciones `INSERT/UPDATE` y asegurar `orders`/`order_items` referencian `tenant_id` correctamente.
- CI/CD, métricas y app móvil: pendientes.
- Seed: falta script/endpoint para crear tenant y asignar usuario admin/staff.

## Próximos pasos prioritarios
1. Verificar y aplicar migraciones en Supabase; crear `tenant` demo con `subdomain` y asignar `admin@ejemplo.com` como `owner` en `tenant_users`.
2. Corregir `app/api/auth/register`: usar `signUp` de Supabase, insertar en `profiles` (`first_name`, `last_name`, `avatar_url`) y crear registro en `tenant_users` con rol.
3. Migrar endpoints de `app/api/pedidos` a `orders`/`order_items` y `products`; actualizar estados, filtros y RLS.
4. Sustituir el `isAdmin` hardcodeado por verificación de rol desde `tenant_users` (en middleware/SSR); añadir headers `x-user-role` confiables.
5. Conectar el Dashboard a datos reales: métricas de `orders` por día, usuarios por tenant, ingresos mensuales.
6. Implementar gestión de tenants en admin: crear/activar/inactivar y asignar usuarios.
7. Crear vistas admin para `usuarios`, `productos`, `configuracion` con CRUD básico.
8. Añadir `api/tenants/create` para alta de tenants (usando funciones SQL o inserts seguros).
9. Añadir `api/dev/seed-tenant` para seed local de tenant y usuario.
10. Documentar `.env.local` y validar `SUPABASE_SERVICE_ROLE_KEY`/`NEXTAUTH_SECRET`.

## Verificación recomendada
- Login y acceso a `/admin/dashboard`; comprobar headers de tenant y rol en requests protegidas.
- Probar RLS: un usuario no debe leer/escribir datos de otros tenants.
- Revisar en Supabase Dashboard que `get_tenant_by_subdomain` y `check_user_tenant_access` funcionen con datos reales.
 - Validar BottomNav:
   - Sin sesión y flag activo: el botón Admin se muestra; al pulsar, redirige a login y luego al panel.
   - Con sesión `staff`: el botón Admin no se muestra.
   - Con sesión `admin/owner`: el botón Admin se muestra.

## Checklist actualizado
- [x] Login email/contraseña con NextAuth
- [ ] Registro con `profiles` + `tenant_users`
- [ ] Crear y asignar tenant demo
- [ ] Migrar APIs de pedidos a `orders`/`order_items`
 - [x] Autorización por roles real en admin (layout + headers)
 - [x] CTA Admin condicionado por rol en BottomNav
- [ ] Dashboard conectado a datos reales
- [ ] CRUD de productos y categorías por tenant
- [ ] Gestión de usuarios por tenant
- [ ] Seed y scripts de desarrollo
- [ ] CI/CD básico
