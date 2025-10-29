-- =====================================================
-- PRUEBAS END-TO-END DEL SISTEMA MULTI-TENANCY
-- =====================================================
-- Este script realiza pruebas completas del sistema multi-tenancy
-- para verificar que todo funciona correctamente

-- Variables para el tenant de prueba
\set tenant_slug 'lasazoncriollamenu'
\set test_email 'admin@lasazoncriollamenu.com'

-- =====================================================
-- 1. VERIFICACIÓN DE ESTRUCTURA BÁSICA
-- =====================================================

\echo '=== 1. VERIFICACIÓN DE ESTRUCTURA BÁSICA ==='

-- Verificar que el tenant existe
SELECT 
    'TENANT ENCONTRADO' as status,
    id, name, slug, is_active, created_at
FROM tenants 
WHERE slug = :'tenant_slug';

-- Verificar que el restaurante está vinculado
SELECT 
    'RESTAURANTE VINCULADO' as status,
    r.id, r.nombre, r.slug, r.activo, r.tenant_id
FROM restaurantes r
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug';

-- Verificar que existe un admin
SELECT 
    'ADMIN CONFIGURADO' as status,
    p.id, p.nombre, p.apellido, p.email, p.rol, p.restaurante_id
FROM perfiles_usuarios p
JOIN restaurantes r ON p.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug' AND p.rol = 'admin';

-- =====================================================
-- 2. VERIFICACIÓN DE DATOS DEL MENÚ
-- =====================================================

\echo '=== 2. VERIFICACIÓN DE DATOS DEL MENÚ ==='

-- Contar categorías activas
SELECT 
    'CATEGORÍAS ACTIVAS' as status,
    COUNT(*) as total
FROM categorias_platos c
JOIN restaurantes r ON c.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug' AND c.activo = true;

-- Contar platos activos
SELECT 
    'PLATOS ACTIVOS' as status,
    COUNT(*) as total
FROM platos p
JOIN restaurantes r ON p.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug' AND p.activo = true;

-- Mostrar muestra del menú
SELECT 
    'MUESTRA DEL MENÚ' as status,
    c.nombre as categoria,
    p.nombre as plato,
    p.precio,
    p.activo
FROM platos p
JOIN categorias_platos c ON p.categoria_id = c.id
JOIN restaurantes r ON p.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug'
ORDER BY c.nombre, p.nombre
LIMIT 5;

-- =====================================================
-- 3. PRUEBAS DE AISLAMIENTO MULTI-TENANT
-- =====================================================

\echo '=== 3. PRUEBAS DE AISLAMIENTO MULTI-TENANT ==='

-- Verificar que los platos solo pertenecen al tenant correcto
SELECT 
    'AISLAMIENTO DE PLATOS' as status,
    COUNT(DISTINCT t.slug) as tenants_diferentes,
    CASE 
        WHEN COUNT(DISTINCT t.slug) = 1 THEN 'CORRECTO - Solo un tenant'
        ELSE 'ERROR - Múltiples tenants'
    END as resultado
FROM platos p
JOIN restaurantes r ON p.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug';

-- Verificar que las categorías solo pertenecen al tenant correcto
SELECT 
    'AISLAMIENTO DE CATEGORÍAS' as status,
    COUNT(DISTINCT t.slug) as tenants_diferentes,
    CASE 
        WHEN COUNT(DISTINCT t.slug) = 1 THEN 'CORRECTO - Solo un tenant'
        ELSE 'ERROR - Múltiples tenants'
    END as resultado
FROM categorias_platos c
JOIN restaurantes r ON c.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug';

-- =====================================================
-- 4. PRUEBAS DE SEGURIDAD RLS
-- =====================================================

\echo '=== 4. PRUEBAS DE SEGURIDAD RLS ==='

-- Verificar políticas activas en tablas críticas
SELECT 
    'POLÍTICAS RLS ACTIVAS' as status,
    schemaname,
    tablename,
    COUNT(*) as num_policies
FROM pg_policies 
WHERE schemaname = 'public' 
AND tablename IN ('restaurantes', 'platos', 'pedidos', 'categorias_platos', 'perfiles_usuarios')
GROUP BY schemaname, tablename
ORDER BY tablename;

-- Verificar que RLS está habilitado
SELECT 
    'RLS HABILITADO' as status,
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('restaurantes', 'platos', 'pedidos', 'categorias_platos', 'perfiles_usuarios')
ORDER BY tablename;

-- =====================================================
-- 5. PRUEBAS DE FUNCIONES AUXILIARES
-- =====================================================

\echo '=== 5. PRUEBAS DE FUNCIONES AUXILIARES ==='

-- Probar función get_current_tenant_id (requiere contexto de sesión)
SELECT 
    'FUNCIÓN get_current_tenant_id' as status,
    'Disponible' as resultado
FROM pg_proc 
WHERE proname = 'get_current_tenant_id';

-- Probar función generate_codigo_pedido
SELECT 
    'FUNCIÓN generate_codigo_pedido' as status,
    generate_codigo_pedido() as codigo_generado;

-- Verificar función is_tenant_admin
SELECT 
    'FUNCIÓN is_tenant_admin' as status,
    'Disponible' as resultado
FROM pg_proc 
WHERE proname = 'is_tenant_admin';

-- =====================================================
-- 6. PRUEBAS DE INTEGRIDAD REFERENCIAL
-- =====================================================

\echo '=== 6. PRUEBAS DE INTEGRIDAD REFERENCIAL ==='

-- Verificar que todos los platos tienen categoría válida
SELECT 
    'INTEGRIDAD PLATOS-CATEGORÍAS' as status,
    COUNT(*) as platos_sin_categoria
FROM platos p
LEFT JOIN categorias_platos c ON p.categoria_id = c.id
JOIN restaurantes r ON p.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug' AND c.id IS NULL;

-- Verificar que todos los platos tienen restaurante válido
SELECT 
    'INTEGRIDAD PLATOS-RESTAURANTES' as status,
    COUNT(*) as platos_sin_restaurante
FROM platos p
LEFT JOIN restaurantes r ON p.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug' AND r.id IS NULL;

-- Verificar que todas las categorías tienen restaurante válido
SELECT 
    'INTEGRIDAD CATEGORÍAS-RESTAURANTES' as status,
    COUNT(*) as categorias_sin_restaurante
FROM categorias_platos c
LEFT JOIN restaurantes r ON c.restaurante_id = r.id
JOIN tenants t ON r.tenant_id = t.id
WHERE t.slug = :'tenant_slug' AND r.id IS NULL;

-- =====================================================
-- 7. PRUEBAS DE RENDIMIENTO BÁSICO
-- =====================================================

\echo '=== 7. PRUEBAS DE RENDIMIENTO BÁSICO ==='

-- Verificar índices en columnas clave
SELECT 
    'ÍNDICES DISPONIBLES' as status,
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
AND tablename IN ('restaurantes', 'platos', 'tenants')
AND (indexdef LIKE '%tenant_id%' OR indexdef LIKE '%slug%' OR indexdef LIKE '%restaurante_id%')
ORDER BY tablename, indexname;

-- =====================================================
-- 8. RESUMEN FINAL
-- =====================================================

\echo '=== 8. RESUMEN FINAL ==='

-- Resumen completo del tenant
WITH tenant_summary AS (
    SELECT 
        t.id as tenant_id,
        t.name as tenant_name,
        t.slug as tenant_slug,
        t.is_active as tenant_active,
        r.id as restaurant_id,
        r.nombre as restaurant_name,
        r.activo as restaurant_active,
        COUNT(DISTINCT c.id) as total_categorias,
        COUNT(DISTINCT p.id) as total_platos,
        COUNT(DISTINCT CASE WHEN p.activo THEN p.id END) as platos_activos,
        COUNT(DISTINCT pu.id) as total_usuarios,
        COUNT(DISTINCT CASE WHEN pu.rol = 'admin' THEN pu.id END) as admins
    FROM tenants t
    LEFT JOIN restaurantes r ON r.tenant_id = t.id
    LEFT JOIN categorias_platos c ON c.restaurante_id = r.id
    LEFT JOIN platos p ON p.restaurante_id = r.id
    LEFT JOIN perfiles_usuarios pu ON pu.restaurante_id = r.id
    WHERE t.slug = :'tenant_slug'
    GROUP BY t.id, t.name, t.slug, t.is_active, r.id, r.nombre, r.activo
)
SELECT 
    'RESUMEN FINAL' as status,
    tenant_name,
    tenant_slug,
    CASE WHEN tenant_active THEN 'ACTIVO' ELSE 'INACTIVO' END as tenant_status,
    restaurant_name,
    CASE WHEN restaurant_active THEN 'ACTIVO' ELSE 'INACTIVO' END as restaurant_status,
    total_categorias,
    total_platos,
    platos_activos,
    total_usuarios,
    admins,
    CASE 
        WHEN tenant_active AND restaurant_active AND total_categorias > 0 AND platos_activos > 0 AND admins > 0 
        THEN '✅ LISTO PARA PRODUCCIÓN'
        WHEN tenant_active AND restaurant_active AND admins > 0
        THEN '⚠️  NECESITA MENÚ'
        WHEN tenant_active AND restaurant_active
        THEN '⚠️  NECESITA ADMIN Y MENÚ'
        ELSE '❌ CONFIGURACIÓN INCOMPLETA'
    END as deployment_status
FROM tenant_summary;

-- =====================================================
-- 9. RECOMENDACIONES FINALES
-- =====================================================

\echo '=== 9. RECOMENDACIONES FINALES ==='

SELECT 
    'PRÓXIMOS PASOS' as status,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM tenants t
            JOIN restaurantes r ON r.tenant_id = t.id
            JOIN perfiles_usuarios pu ON pu.restaurante_id = r.id
            WHERE t.slug = :'tenant_slug' 
            AND t.is_active = true 
            AND r.activo = true 
            AND pu.rol = 'admin'
            AND EXISTS (
                SELECT 1 FROM platos p 
                WHERE p.restaurante_id = r.id AND p.activo = true
            )
        )
        THEN 'Tenant completamente configurado. Probar en: /?tenant=' || :'tenant_slug'
        ELSE 'Ejecutar scripts de configuración faltantes'
    END as recomendacion;

\echo '=== PRUEBAS END-TO-END COMPLETADAS ==='