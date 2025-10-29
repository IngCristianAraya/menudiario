# ✅ Checklist: Migración a RLS (Un Solo Proyecto Supabase)

## 📋 Pre-requisitos
- [ ] Tienes acceso al dashboard de Supabase de tu proyecto principal
- [ ] Tienes las credenciales: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE`
- [ ] Backup de tu base de datos actual (por seguridad)

## 🔧 Paso 1: Ejecutar Migración RLS
- [ ] Abrir Supabase Dashboard → SQL Editor
- [ ] Copiar contenido de `supabase/migrations/20251028_rls_single_project_multitenant.sql`
- [ ] Ejecutar la migración completa
- [ ] Verificar que no hay errores en la ejecución
- [ ] Confirmar que las tablas tienen RLS activado:
  ```sql
  SELECT schemaname, tablename, rowsecurity 
  FROM pg_tables 
  WHERE tablename IN ('perfiles_usuarios', 'restaurantes', 'platos', 'pedidos', 'items_pedido', 'menus_diarios', 'pedidos_diarios');
  ```

## 🏢 Paso 2: Crear Restaurantes Base
- [ ] Insertar restaurantes de prueba:
  ```sql
  INSERT INTO restaurantes (id, nombre, subdominio, activo) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'La Cabañita', 'lacabanita', true),
  ('550e8400-e29b-41d4-a716-446655440002', 'The Point', 'thepoint', true);
  ```
- [ ] Verificar inserción exitosa

## 👥 Paso 3: Configurar Variables de Entorno
- [ ] En Vercel, mantener solo variables globales:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY` 
  - `SUPABASE_SERVICE_ROLE`
- [ ] Eliminar variables por tenant (ej: `SUPABASE_URL__lacabanita`)
- [ ] Redesplegar aplicación

## 🔐 Paso 4: Crear Usuarios de Prueba
- [ ] Registrar usuario para "lacabanita":
  - Email: `admin@lacabanita.test`
  - Contraseña: temporal
- [ ] Registrar usuario para "thepoint":
  - Email: `admin@thepoint.test`
  - Contraseña: temporal
- [ ] Verificar que se crean en `auth.users`

## 📝 Paso 5: Vincular Usuarios a Restaurantes
- [ ] Ejecutar script de vinculación (ver `scripts/register-tenant-rls.ps1`)
- [ ] O insertar manualmente en `perfiles_usuarios`:
  ```sql
  -- Obtener IDs de usuarios de auth.users
  SELECT id, email FROM auth.users;
  
  -- Insertar perfiles (reemplazar UUIDs reales)
  INSERT INTO perfiles_usuarios (id, restaurante_id, rol, nombre_completo) VALUES
  ('uuid-del-usuario-lacabanita', '550e8400-e29b-41d4-a716-446655440001', 'admin', 'Admin La Cabañita'),
  ('uuid-del-usuario-thepoint', '550e8400-e29b-41d4-a716-446655440002', 'admin', 'Admin The Point');
  ```

## 🧪 Paso 6: Pruebas de Aislamiento
- [ ] Login como usuario de "lacabanita"
- [ ] Crear un plato:
  ```sql
  INSERT INTO platos (nombre, precio, restaurante_id) 
  VALUES ('Ceviche', 25.00, '550e8400-e29b-41d4-a716-446655440001');
  ```
- [ ] Verificar que solo ve sus platos:
  ```sql
  SELECT * FROM platos; -- Debe mostrar solo platos de lacabanita
  ```
- [ ] Login como usuario de "thepoint"
- [ ] Verificar que NO ve platos de "lacabanita"
- [ ] Crear plato para "thepoint" y verificar aislamiento

## 🚨 Paso 7: Pruebas de Seguridad
- [ ] Intentar insertar con `restaurante_id` incorrecto:
  ```sql
  -- Logueado como lacabanita, intentar crear para thepoint
  INSERT INTO platos (nombre, precio, restaurante_id) 
  VALUES ('Hack Test', 1.00, '550e8400-e29b-41d4-a716-446655440002');
  ```
- [ ] Debe fallar con "permission denied"
- [ ] Intentar SELECT con filtro manual:
  ```sql
  SELECT * FROM platos WHERE restaurante_id = '550e8400-e29b-41d4-a716-446655440002';
  ```
- [ ] Debe retornar vacío (RLS bloquea)

## 📱 Paso 8: Pruebas en Aplicación
- [ ] Acceder a `lacabanita.tubarrio.pe` (o localhost con subdomain)
- [ ] Login con usuario de lacabanita
- [ ] Crear menú del día, verificar que se guarda con `restaurante_id` correcto
- [ ] Crear pedido, verificar aislamiento
- [ ] Repetir para "thepoint"
- [ ] Verificar que cada tenant solo ve sus datos

## 🔄 Paso 9: Migración de Datos Existentes (si aplica)
- [ ] Si tienes datos previos sin `restaurante_id`:
  ```sql
  -- Ejemplo: asignar platos existentes a un restaurante
  UPDATE platos SET restaurante_id = '550e8400-e29b-41d4-a716-446655440001' 
  WHERE restaurante_id IS NULL AND created_at < '2024-01-01';
  ```
- [ ] Verificar que todos los registros tienen `restaurante_id`

## ✅ Paso 10: Validación Final
- [ ] Todos los usuarios pueden login
- [ ] Cada tenant ve solo sus datos
- [ ] No hay errores de "permission denied" en operaciones normales
- [ ] Aplicación funciona correctamente en subdominios
- [ ] Backup de la base migrada exitosamente

## 🚨 Rollback (si algo falla)
- [ ] Restaurar backup de base de datos
- [ ] Revertir variables de entorno en Vercel
- [ ] Redesplegar versión anterior

## 📞 Soporte
Si encuentras errores:
1. Revisar logs de Supabase (Dashboard → Logs)
2. Verificar que `perfiles_usuarios` tiene filas para todos los usuarios
3. Confirmar que todas las tablas tienen `restaurante_id` no nulo
4. Validar políticas RLS están activas

---
**Tiempo estimado:** 30-45 minutos
**Riesgo:** Bajo (con backup previo)