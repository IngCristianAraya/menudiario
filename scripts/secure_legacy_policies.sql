-- =====================================================
-- SCRIPT: Endurecimiento de Políticas RLS Legacy
-- PROPÓSITO: Eliminar accesos anónimos y asegurar el modelo legacy
-- FECHA: 2025-10-28
-- =====================================================

-- IMPORTANTE: Ejecutar este script con Service Role Key
-- Este script elimina las vulnerabilidades de seguridad identificadas

BEGIN;

-- =====================================================
-- 1. ELIMINAR POLÍTICAS INSEGURAS EXISTENTES
-- =====================================================

-- Eliminar política de inserción pública en restaurantes
DROP POLICY IF EXISTS "restaurantes_insert_public" ON public.restaurantes;

-- Eliminar políticas con acceso anónimo en platos
DROP POLICY IF EXISTS "platos_select_same_restaurant" ON public.platos;

-- Eliminar políticas con acceso anónimo en pedidos_diarios
DROP POLICY IF EXISTS "pd_select_same_rest" ON public.pedidos_diarios;
DROP POLICY IF EXISTS "pd_write_same_rest" ON public.pedidos_diarios;

-- Eliminar política de selección anónima en restaurantes
DROP POLICY IF EXISTS "restaurantes_select_own" ON public.restaurantes;

-- =====================================================
-- 2. CREAR POLÍTICAS SEGURAS PARA RESTAURANTES
-- =====================================================

-- Solo admins pueden insertar restaurantes
CREATE POLICY "restaurantes_insert_admin_only" ON public.restaurantes
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM perfiles_usuarios pu
            WHERE pu.id = auth.uid() 
            AND pu.rol = 'admin'
        )
    );

-- Solo usuarios del restaurante pueden ver su restaurante
CREATE POLICY "restaurantes_select_own_secure" ON public.restaurantes
    FOR SELECT
    USING (
        id = (
            SELECT perfiles_usuarios.restaurante_id
            FROM perfiles_usuarios
            WHERE perfiles_usuarios.id = auth.uid()
        )
    );

-- =====================================================
-- 3. CREAR POLÍTICAS SEGURAS PARA PLATOS
-- =====================================================

-- Solo usuarios del mismo restaurante pueden ver platos
CREATE POLICY "platos_select_same_restaurant_secure" ON public.platos
    FOR SELECT
    USING (
        restaurante_id = (
            SELECT perfiles_usuarios.restaurante_id
            FROM perfiles_usuarios
            WHERE perfiles_usuarios.id = auth.uid()
        )
    );

-- =====================================================
-- 4. CREAR POLÍTICAS SEGURAS PARA PEDIDOS DIARIOS
-- =====================================================

-- Solo usuarios del mismo restaurante pueden ver pedidos diarios
CREATE POLICY "pedidos_diarios_select_same_rest_secure" ON public.pedidos_diarios
    FOR SELECT
    USING (
        restaurante_id = (
            SELECT perfiles_usuarios.restaurante_id
            FROM perfiles_usuarios
            WHERE perfiles_usuarios.id = auth.uid()
        )
    );

-- Solo usuarios del mismo restaurante pueden modificar pedidos diarios
CREATE POLICY "pedidos_diarios_write_same_rest_secure" ON public.pedidos_diarios
    FOR ALL
    USING (
        restaurante_id = (
            SELECT perfiles_usuarios.restaurante_id
            FROM perfiles_usuarios
            WHERE perfiles_usuarios.id = auth.uid()
        )
    )
    WITH CHECK (
        restaurante_id = (
            SELECT perfiles_usuarios.restaurante_id
            FROM perfiles_usuarios
            WHERE perfiles_usuarios.id = auth.uid()
        )
    );

-- =====================================================
-- 5. POLÍTICA ESPECIAL PARA LECTURA PÚBLICA DE PLATOS ACTIVOS
-- =====================================================
-- Esta política permite que clientes no autenticados vean el menú
-- pero solo platos activos y con categoría válida

CREATE POLICY "platos_public_menu_read" ON public.platos
    FOR SELECT
    USING (
        activo = true 
        AND EXISTS (
            SELECT 1 FROM categorias_platos cp
            WHERE cp.id = platos.categoria_id
        )
        AND EXISTS (
            SELECT 1 FROM restaurantes r
            WHERE r.id = platos.restaurante_id
            AND r.activo = true
        )
    );

-- =====================================================
-- 6. POLÍTICA PARA LECTURA PÚBLICA DE RESTAURANTES ACTIVOS
-- =====================================================
-- Permite ver información básica de restaurantes activos para el catálogo público

CREATE POLICY "restaurantes_public_catalog_read" ON public.restaurantes
    FOR SELECT
    USING (
        activo = true
        AND tenant_id IS NOT NULL  -- Solo restaurantes vinculados a tenants
    );

-- =====================================================
-- 7. VERIFICACIÓN DE POLÍTICAS
-- =====================================================

-- Mostrar todas las políticas activas para verificación
DO $$
BEGIN
    RAISE NOTICE '=== POLÍTICAS ACTIVAS DESPUÉS DEL ENDURECIMIENTO ===';
    RAISE NOTICE 'Ejecutar las siguientes consultas para verificar:';
    RAISE NOTICE 'SELECT schemaname, tablename, policyname, cmd, qual FROM pg_policies WHERE schemaname = ''public'' ORDER BY tablename, policyname;';
END $$;

COMMIT;

-- =====================================================
-- NOTAS DE SEGURIDAD
-- =====================================================
/*
CAMBIOS REALIZADOS:

1. ELIMINADO: Acceso anónimo completo (OR auth.uid() IS NULL)
2. ELIMINADO: Inserción pública de restaurantes
3. AÑADIDO: Políticas restrictivas basadas en perfiles_usuarios
4. AÑADIDO: Lectura pública controlada solo para:
   - Platos activos con categoría válida
   - Restaurantes activos vinculados a tenants

IMPACTO:
- Los usuarios deben estar autenticados para operaciones CRUD
- Los clientes pueden ver el menú público (platos activos)
- Los clientes pueden ver el catálogo de restaurantes activos
- Solo admins pueden crear nuevos restaurantes
- Cada usuario solo ve datos de su restaurante

PRÓXIMOS PASOS:
1. Ejecutar seed_legacy_demo.sql para crear datos mínimos
2. Probar acceso con diferentes roles
3. Validar que la app funcione correctamente
*/