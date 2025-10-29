# Modo multi‑tenant en un solo proyecto Supabase (RLS)

Este documento explica cómo operar con un único proyecto de Supabase (plan gratuito) y aislar los datos por restaurante usando columnas `restaurante_id` y políticas de Row Level Security (RLS).

## Objetivo
- Un solo Supabase para todos los restaurantes.
- Aislamiento lógico: cada usuario sólo ve/gestiona datos del restaurante al que pertenece.
- Cero despliegues extra: una sola app en Vercel, un set de variables globales (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE`).

## Requisitos de esquema
- Tabla `restaurantes`: `id uuid PK`, datos del restaurante.
- Tabla `perfiles_usuarios`: `id uuid PK` (igual a `auth.users.id`), `restaurante_id uuid`, `rol text` (`admin`, `mozo`, etc.).
- Tablas operativas con `restaurante_id`: `platos`, `pedidos`, `items_pedido`, `menus_diarios`, `pedidos_diarios`.

Si alguna tabla diaria no tenía `restaurante_id`, la migración `20251028_rls_single_project_multitenant.sql` lo añade y activa RLS con políticas por restaurante.

## Políticas RLS aplicadas
- `perfiles_usuarios`: cada usuario lee/actualiza sólo su propio perfil.
- `restaurantes`: lectura del propio restaurante; escritura sólo `admin` del mismo restaurante.
- `platos`: lectura por mismo restaurante; escritura sólo `admin` del restaurante.
- `pedidos`: select/insert/update restringidos al mismo restaurante.
- `items_pedido`: restringidos vía el `pedido` al mismo restaurante.
- `menus_diarios`, `pedidos_diarios`: restringidos al mismo restaurante; escritura sólo `admin` en `menus_diarios`.

Estas políticas usan `auth.uid()` y subconsultas a `perfiles_usuarios` para verificar el `restaurante_id` del usuario.

## Flujo de alta de usuarios
1. Registrar usuario con `auth.signUp` en Supabase.
2. Insertar fila en `perfiles_usuarios` con `id = auth_user.id`, `restaurante_id`, `rol`.
3. A partir de ahí, RLS filtra automáticamente todo.

## Variables de entorno en Vercel
- Usar sólo las globales del proyecto:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE` (para scripts admin, nunca en el navegador)

No se necesitan variables por restaurante.

## Buenas prácticas
- Siempre incluir `restaurante_id` en inserts de tablas operativas.
- Mantener `perfiles_usuarios` sincronizado con `auth.users` (trigger o lógica de app).
- Usar el `service_role` para tareas batch o backoffice que deban ignorar RLS.

## Verificación rápida
1. Autentica con un usuario de `Restaurante A`.
2. Intenta leer/crear `pedidos` de `Restaurante B` → debe fallar (RLS).
3. Crea `platos` y `menus_diarios` en `A` → debe funcionar.

## Problemas comunes
- "permission denied for table": falta `perfiles_usuarios` o su `restaurante_id` no coincide.
- Políticas antiguas abiertas en `menus_diarios` o `pedidos_diarios`: ya se eliminan en la migración nueva.