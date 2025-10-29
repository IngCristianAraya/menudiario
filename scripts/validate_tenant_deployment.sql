-- =====================================================
-- SCRIPT: Validación Completa del Tenant "La Sazón Criolla"
-- PROPÓSITO: Verificar que el despliegue del tenant sea exitoso
-- FECHA: 2025-10-28
-- =====================================================

-- Este script valida todos los aspectos del despliegue multi-tenant

BEGIN;

-- =====================================================
-- 1. VALIDACIÓN DE ESTRUCTURA BÁSICA
-- =====================================================

DO $$
DECLARE
    v_tenant_id UUID := '3bdf61e0-6a4f-41ce-a30b-2003e925c83e';
    v_restaurante_id UUID := 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f';
    v_tenant_count INTEGER;
    v_restaurante_count INTEGER;
    v_admin_count INTEGER;
    v_platos_count INTEGER;
    v_categorias_count INTEGER;
    v_tenant_users_count INTEGER;
BEGIN
    
    RAISE NOTICE '=== VALIDACIÓN DEL TENANT LA SAZÓN CRIOLLA ===';
    RAISE NOTICE 'Tenant ID: %', v_tenant_id;
    RAISE NOTICE 'Restaurante ID: %', v_restaurante_id;
    RAISE NOTICE '';
    
    -- Verificar tenant
    SELECT COUNT(*) INTO v_tenant_count 
    FROM tenants 
    WHERE id = v_tenant_id AND is_active = true;
    
    IF v_tenant_count = 0 THEN
        RAISE EXCEPTION 'FALLO: Tenant no encontrado o inactivo';
    END IF;
    RAISE NOTICE '✓ Tenant encontrado y activo';
    
    -- Verificar restaurante
    SELECT COUNT(*) INTO v_restaurante_count 
    FROM restaurantes 
    WHERE id = v_restaurante_id AND tenant_id = v_tenant_id AND activo = true;
    
    IF v_restaurante_count = 0 THEN
        RAISE EXCEPTION 'FALLO: Restaurante no encontrado, no vinculado al tenant, o inactivo';
    END IF;
    RAISE NOTICE '✓ Restaurante encontrado, vinculado y activo';
    
    -- Verificar admin
    SELECT COUNT(*) INTO v_admin_count 
    FROM perfiles_usuarios 
    WHERE restaurante_id = v_restaurante_id AND rol = 'admin';
    
    IF v_admin_count = 0 THEN
        RAISE WARNING 'ADVERTENCIA: No hay usuarios admin para este restaurante';
    ELSE
        RAISE NOTICE '✓ Usuario(s) admin encontrado(s): %', v_admin_count;
    END IF;
    
    -- Verificar categorías
    SELECT COUNT(*) INTO v_categorias_count 
    FROM categorias_platos 
    WHERE restaurante_id = v_restaurante_id AND activo = true;
    
    IF v_categorias_count = 0 THEN
        RAISE WARNING 'ADVERTENCIA: No hay categorías de platos';
    ELSE
        RAISE NOTICE '✓ Categorías de platos encontradas: %', v_categorias_count;
    END IF;
    
    -- Verificar platos
    SELECT COUNT(*) INTO v_platos_count 
    FROM platos 
    WHERE restaurante_id = v_restaurante_id AND activo = true;
    
    IF v_platos_count = 0 THEN
        RAISE WARNING 'ADVERTENCIA: No hay platos activos';
    ELSE
        RAISE NOTICE '✓ Platos activos encontrados: %', v_platos_count;
    END IF;
    
    -- Verificar tenant_users
    SELECT COUNT(*) INTO v_tenant_users_count 
    FROM tenant_users 
    WHERE tenant_id = v_tenant_id;
    
    IF v_tenant_users_count = 0 THEN
        RAISE WARNING 'ADVERTENCIA: No hay usuarios vinculados al tenant en el modelo nuevo';
    ELSE
        RAISE NOTICE '✓ Usuarios del tenant encontrados: %', v_tenant_users_count;
    END IF;
    
END $$;

-- =====================================================
-- 2. VALIDACIÓN DE POLÍTICAS RLS
-- =====================================================

RAISE NOTICE '';
RAISE NOTICE '=== VALIDACIÓN DE POLÍTICAS RLS ===';

-- Verificar que RLS esté habilitado
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('tenants', 'restaurantes', 'perfiles_usuarios', 'platos', 'pedidos', 'items_pedido', 'categorias_platos')
ORDER BY tablename;

-- Contar políticas por tabla
SELECT 
    tablename,
    COUNT(*) as total_policies,
    COUNT(CASE WHEN cmd = 'SELECT' THEN 1 END) as select_policies,
    COUNT(CASE WHEN cmd = 'INSERT' THEN 1 END) as insert_policies,
    COUNT(CASE WHEN cmd = 'UPDATE' THEN 1 END) as update_policies,
    COUNT(CASE WHEN cmd = 'DELETE' THEN 1 END) as delete_policies,
    COUNT(CASE WHEN cmd = 'ALL' THEN 1 END) as all_policies
FROM pg_policies 
WHERE schemaname = 'public'
AND tablename IN ('tenants', 'restaurantes', 'perfiles_usuarios', 'platos', 'pedidos', 'items_pedido', 'categorias_platos')
GROUP BY tablename
ORDER BY tablename;

-- =====================================================
-- 3. VALIDACIÓN DE INTEGRIDAD REFERENCIAL
-- =====================================================

RAISE NOTICE '';
RAISE NOTICE '=== VALIDACIÓN DE INTEGRIDAD REFERENCIAL ===';

-- Verificar que todos los restaurantes tengan tenant_id válido (excepto legacy)
SELECT 
    'Restaurantes sin tenant_id' as check_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 2 THEN 'ADVERTENCIA: Más restaurantes legacy de lo esperado' 
         ELSE 'OK' END as status
FROM restaurantes 
WHERE tenant_id IS NULL;

-- Verificar que todos los platos tengan restaurante_id válido
SELECT 
    'Platos huérfanos' as check_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 0 THEN 'ERROR: Platos sin restaurante' 
         ELSE 'OK' END as status
FROM platos p
LEFT JOIN restaurantes r ON p.restaurante_id = r.id
WHERE r.id IS NULL;

-- Verificar que todos los perfiles tengan restaurante_id válido
SELECT 
    'Perfiles huérfanos' as check_name,
    COUNT(*) as count,
    CASE WHEN COUNT(*) > 0 THEN 'ERROR: Perfiles sin restaurante' 
         ELSE 'OK' END as status
FROM perfiles_usuarios pu
LEFT JOIN restaurantes r ON pu.restaurante_id = r.id
WHERE r.id IS NULL AND pu.restaurante_id IS NOT NULL;

-- =====================================================
-- 4. VALIDACIÓN DE DATOS DEL TENANT
-- =====================================================

RAISE NOTICE '';
RAISE NOTICE '=== DATOS DEL TENANT LA SAZÓN CRIOLLA ===';

-- Información del tenant
SELECT 
    'TENANT' as tipo,
    name as nombre,
    slug,
    contact_email as email,
    is_active as activo,
    created_at
FROM tenants 
WHERE id = '3bdf61e0-6a4f-41ce-a30b-2003e925c83e';

-- Información del restaurante
SELECT 
    'RESTAURANTE' as tipo,
    nombre,
    slug,
    telefono,
    email,
    activo,
    created_at
FROM restaurantes 
WHERE id = 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f';

-- Usuarios admin del restaurante
SELECT 
    'ADMIN' as tipo,
    nombre || ' ' || COALESCE(apellido, '') as nombre_completo,
    telefono,
    rol,
    created_at
FROM perfiles_usuarios 
WHERE restaurante_id = 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f'
AND rol = 'admin';

-- Resumen de platos por categoría
SELECT 
    cp.nombre as categoria,
    COUNT(p.id) as total_platos,
    COUNT(CASE WHEN p.activo THEN 1 END) as platos_activos,
    ROUND(AVG(p.precio), 0) as precio_promedio
FROM categorias_platos cp
LEFT JOIN platos p ON cp.id = p.categoria_id
WHERE cp.restaurante_id = 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f'
GROUP BY cp.id, cp.nombre
ORDER BY cp.nombre;

-- =====================================================
-- 5. VALIDACIÓN DE CONFIGURACIÓN MULTI-TENANT
-- =====================================================

RAISE NOTICE '';
RAISE NOTICE '=== CONFIGURACIÓN MULTI-TENANT ===';

-- Usuarios del tenant en el modelo nuevo
SELECT 
    tu.role as rol_tenant,
    COALESCE(pu.nombre, 'Sin perfil legacy') as nombre_usuario,
    tu.created_at
FROM tenant_users tu
LEFT JOIN perfiles_usuarios pu ON tu.user_id = pu.id
WHERE tu.tenant_id = '3bdf61e0-6a4f-41ce-a30b-2003e925c83e'
ORDER BY tu.role, tu.created_at;

-- =====================================================
-- 6. PRUEBAS DE FUNCIONES AUXILIARES
-- =====================================================

RAISE NOTICE '';
RAISE NOTICE '=== PRUEBAS DE FUNCIONES ===';

-- Probar función de generación de código de pedido
SELECT 
    'generate_codigo_pedido()' as funcion,
    generate_codigo_pedido() as resultado,
    'OK' as status;

-- Verificar que las funciones multi-tenant existen
SELECT 
    routine_name as funcion,
    routine_type as tipo,
    'Existe' as status
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name IN ('get_current_tenant_id', 'is_tenant_admin', 'get_auth_user_id_by_email')
ORDER BY routine_name;

-- =====================================================
-- 7. RECOMENDACIONES FINALES
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== RECOMENDACIONES PARA EL DESPLIEGUE ===';
    RAISE NOTICE '1. Ejecutar secure_legacy_policies.sql si no se ha hecho';
    RAISE NOTICE '2. Crear usuario admin@lasazoncriolla.com en Supabase Auth';
    RAISE NOTICE '3. Ejecutar seed_legacy_demo.sql para datos iniciales';
    RAISE NOTICE '4. Probar login y navegación en la aplicación';
    RAISE NOTICE '5. Verificar que el slug "lasazoncriollamenu" resuelva correctamente';
    RAISE NOTICE '6. Probar creación de pedidos con diferentes roles';
    RAISE NOTICE '';
    RAISE NOTICE '=== URLS DE PRUEBA ===';
    RAISE NOTICE 'Desarrollo: http://localhost:3001/?tenant=lasazoncriollamenu';
    RAISE NOTICE 'Producción: https://tudominio.com/?tenant=lasazoncriollamenu';
    RAISE NOTICE '';
END $$;

COMMIT;

-- =====================================================
-- QUERIES ADICIONALES PARA DEBUGGING
-- =====================================================

-- Uncomment estas queries si necesitas debugging adicional:

/*
-- Ver todas las políticas activas
SELECT schemaname, tablename, policyname, cmd, qual, with_check 
FROM pg_policies 
WHERE schemaname = 'public' 
ORDER BY tablename, policyname;

-- Ver todos los índices
SELECT schemaname, tablename, indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('tenants', 'restaurantes', 'platos', 'pedidos')
ORDER BY tablename, indexname;

-- Ver todas las foreign keys
SELECT 
    tc.table_name, 
    kcu.column_name, 
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name 
FROM information_schema.table_constraints AS tc 
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY' 
AND tc.table_schema = 'public'
ORDER BY tc.table_name, kcu.column_name;
*/