-- =====================================================
-- SCRIPT: Seed Mínimo para Tenant "La Sazón Criolla"
-- PROPÓSITO: Crear datos mínimos necesarios para el funcionamiento
-- FECHA: 2025-10-28
-- =====================================================

-- IMPORTANTE: Ejecutar este script con Service Role Key
-- Este script es idempotente - se puede ejecutar múltiples veces

BEGIN;

-- =====================================================
-- VARIABLES DEL TENANT "LA SAZÓN CRIOLLA"
-- =====================================================
-- Basado en los datos reales encontrados en el JSON de Supabase

DO $$
DECLARE
    v_tenant_id UUID := '3bdf61e0-6a4f-41ce-a30b-2003e925c83e';
    v_restaurante_id UUID := 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f';
    v_admin_email TEXT := 'admin@lasazoncriolla.com';
    v_admin_user_id UUID;
    v_categoria_principales UUID;
    v_categoria_bebidas UUID;
    v_categoria_postres UUID;
BEGIN
    
    RAISE NOTICE '=== INICIANDO SEED PARA LA SAZÓN CRIOLLA ===';
    
    -- =====================================================
    -- 1. VERIFICAR QUE EL TENANT Y RESTAURANTE EXISTEN
    -- =====================================================
    
    IF NOT EXISTS (SELECT 1 FROM tenants WHERE id = v_tenant_id) THEN
        RAISE EXCEPTION 'Tenant La Sazón Criolla no encontrado. ID esperado: %', v_tenant_id;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM restaurantes WHERE id = v_restaurante_id) THEN
        RAISE EXCEPTION 'Restaurante La Sazón Criolla no encontrado. ID esperado: %', v_restaurante_id;
    END IF;
    
    RAISE NOTICE 'Tenant y restaurante verificados correctamente';
    
    -- =====================================================
    -- 2. OBTENER O CREAR USUARIO ADMIN
    -- =====================================================
    
    -- Buscar el usuario admin por email usando la función segura
    SELECT get_auth_user_id_by_email(v_admin_email) INTO v_admin_user_id;
    
    IF v_admin_user_id IS NULL THEN
        RAISE NOTICE 'Usuario admin no encontrado. Debe crear el usuario % en Supabase Auth primero', v_admin_email;
        RAISE NOTICE 'Puede usar el panel de Supabase o el endpoint de registro';
        -- No podemos crear usuarios auth desde SQL, solo perfiles
        RETURN;
    END IF;
    
    RAISE NOTICE 'Usuario admin encontrado: %', v_admin_user_id;
    
    -- =====================================================
    -- 3. CREAR PERFIL DE USUARIO ADMIN (IDEMPOTENTE)
    -- =====================================================
    
    INSERT INTO perfiles_usuarios (
        id,
        nombre,
        apellido,
        telefono,
        rol,
        restaurante_id,
        created_at,
        updated_at
    ) VALUES (
        v_admin_user_id,
        'Administrador',
        'La Sazón Criolla',
        '+57 300 123 4567',
        'admin',
        v_restaurante_id,
        NOW(),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        nombre = EXCLUDED.nombre,
        apellido = EXCLUDED.apellido,
        telefono = EXCLUDED.telefono,
        rol = EXCLUDED.rol,
        restaurante_id = EXCLUDED.restaurante_id,
        updated_at = NOW();
    
    RAISE NOTICE 'Perfil de admin creado/actualizado';
    
    -- =====================================================
    -- 4. CREAR CATEGORÍAS DE PLATOS (IDEMPOTENTE)
    -- =====================================================
    
    -- Categoría: Platos Principales
    INSERT INTO categorias_platos (
        id,
        nombre,
        descripcion,
        restaurante_id,
        activo,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        'Platos Principales',
        'Nuestros deliciosos platos principales de la cocina criolla',
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (nombre, restaurante_id) DO UPDATE SET
        descripcion = EXCLUDED.descripcion,
        activo = EXCLUDED.activo,
        updated_at = NOW()
    RETURNING id INTO v_categoria_principales;
    
    -- Si ya existía, obtener su ID
    IF v_categoria_principales IS NULL THEN
        SELECT id INTO v_categoria_principales 
        FROM categorias_platos 
        WHERE nombre = 'Platos Principales' AND restaurante_id = v_restaurante_id;
    END IF;
    
    -- Categoría: Bebidas
    INSERT INTO categorias_platos (
        id,
        nombre,
        descripcion,
        restaurante_id,
        activo,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        'Bebidas',
        'Refrescantes bebidas naturales y tradicionales',
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (nombre, restaurante_id) DO UPDATE SET
        descripcion = EXCLUDED.descripcion,
        activo = EXCLUDED.activo,
        updated_at = NOW()
    RETURNING id INTO v_categoria_bebidas;
    
    IF v_categoria_bebidas IS NULL THEN
        SELECT id INTO v_categoria_bebidas 
        FROM categorias_platos 
        WHERE nombre = 'Bebidas' AND restaurante_id = v_restaurante_id;
    END IF;
    
    -- Categoría: Postres
    INSERT INTO categorias_platos (
        id,
        nombre,
        descripcion,
        restaurante_id,
        activo,
        created_at,
        updated_at
    ) VALUES (
        gen_random_uuid(),
        'Postres',
        'Dulces tradicionales y postres caseros',
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (nombre, restaurante_id) DO UPDATE SET
        descripcion = EXCLUDED.descripcion,
        activo = EXCLUDED.activo,
        updated_at = NOW()
    RETURNING id INTO v_categoria_postres;
    
    IF v_categoria_postres IS NULL THEN
        SELECT id INTO v_categoria_postres 
        FROM categorias_platos 
        WHERE nombre = 'Postres' AND restaurante_id = v_restaurante_id;
    END IF;
    
    RAISE NOTICE 'Categorías creadas: Principales=%, Bebidas=%, Postres=%', 
                 v_categoria_principales, v_categoria_bebidas, v_categoria_postres;
    
    -- =====================================================
    -- 5. CREAR PLATOS DE EJEMPLO (IDEMPOTENTE)
    -- =====================================================
    
    -- Platos Principales
    INSERT INTO platos (
        nombre,
        descripcion,
        precio,
        categoria_id,
        restaurante_id,
        activo,
        created_at,
        updated_at
    ) VALUES 
    (
        'Bandeja Paisa Tradicional',
        'Frijoles, arroz, carne molida, chicharrón, chorizo, huevo frito, patacón y aguacate',
        25000,
        v_categoria_principales,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    ),
    (
        'Sancocho de Gallina',
        'Tradicional sancocho con gallina criolla, yuca, plátano, mazorca y cilantro',
        18000,
        v_categoria_principales,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    ),
    (
        'Ajiaco Santafereño',
        'Sopa tradicional con pollo, papas criollas, guascas y crema de leche',
        16000,
        v_categoria_principales,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    ),
    (
        'Pescado Frito con Patacones',
        'Pescado fresco frito acompañado de patacones, arroz y ensalada',
        22000,
        v_categoria_principales,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (nombre, restaurante_id) DO UPDATE SET
        descripcion = EXCLUDED.descripcion,
        precio = EXCLUDED.precio,
        categoria_id = EXCLUDED.categoria_id,
        activo = EXCLUDED.activo,
        updated_at = NOW();
    
    -- Bebidas
    INSERT INTO platos (
        nombre,
        descripcion,
        precio,
        categoria_id,
        restaurante_id,
        activo,
        created_at,
        updated_at
    ) VALUES 
    (
        'Limonada Natural',
        'Refrescante limonada con hielo y azúcar al gusto',
        4000,
        v_categoria_bebidas,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    ),
    (
        'Jugo de Lulo',
        'Jugo natural de lulo, dulce y refrescante',
        5000,
        v_categoria_bebidas,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    ),
    (
        'Agua Panela con Limón',
        'Tradicional bebida caliente de panela con limón',
        3000,
        v_categoria_bebidas,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (nombre, restaurante_id) DO UPDATE SET
        descripcion = EXCLUDED.descripcion,
        precio = EXCLUDED.precio,
        categoria_id = EXCLUDED.categoria_id,
        activo = EXCLUDED.activo,
        updated_at = NOW();
    
    -- Postres
    INSERT INTO platos (
        nombre,
        descripcion,
        precio,
        categoria_id,
        restaurante_id,
        activo,
        created_at,
        updated_at
    ) VALUES 
    (
        'Tres Leches Casero',
        'Delicioso postre de tres leches con canela',
        8000,
        v_categoria_postres,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    ),
    (
        'Flan de Coco',
        'Cremoso flan de coco con caramelo',
        7000,
        v_categoria_postres,
        v_restaurante_id,
        true,
        NOW(),
        NOW()
    )
    ON CONFLICT (nombre, restaurante_id) DO UPDATE SET
        descripcion = EXCLUDED.descripcion,
        precio = EXCLUDED.precio,
        categoria_id = EXCLUDED.categoria_id,
        activo = EXCLUDED.activo,
        updated_at = NOW();
    
    RAISE NOTICE 'Platos de ejemplo creados/actualizados';
    
    -- =====================================================
    -- 6. CREAR TENANT_USER PARA EL MODELO MULTI-TENANT
    -- =====================================================
    
    INSERT INTO tenant_users (
        user_id,
        tenant_id,
        role,
        created_at,
        updated_at
    ) VALUES (
        v_admin_user_id,
        v_tenant_id,
        'super_admin',
        NOW(),
        NOW()
    )
    ON CONFLICT (user_id, tenant_id) DO UPDATE SET
        role = EXCLUDED.role,
        updated_at = NOW();
    
    RAISE NOTICE 'Relación tenant_user creada para super_admin';
    
    -- =====================================================
    -- 7. RESUMEN FINAL
    -- =====================================================
    
    RAISE NOTICE '=== SEED COMPLETADO EXITOSAMENTE ===';
    RAISE NOTICE 'Tenant: La Sazón Criolla (%)', v_tenant_id;
    RAISE NOTICE 'Restaurante: % (%)', 'La Sazón Criolla', v_restaurante_id;
    RAISE NOTICE 'Admin: % (%)', v_admin_email, v_admin_user_id;
    RAISE NOTICE 'Categorías: 3 creadas';
    RAISE NOTICE 'Platos: 9 creados';
    RAISE NOTICE 'Tenant User: super_admin asignado';
    
END $$;

COMMIT;

-- =====================================================
-- VERIFICACIONES POST-SEED
-- =====================================================

-- Verificar datos creados
SELECT 
    'TENANT' as tipo,
    t.name as nombre,
    t.slug,
    t.is_active as activo
FROM tenants t 
WHERE t.id = '3bdf61e0-6a4f-41ce-a30b-2003e925c83e'

UNION ALL

SELECT 
    'RESTAURANTE' as tipo,
    r.nombre,
    r.slug,
    r.activo::text
FROM restaurantes r 
WHERE r.id = 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f'

UNION ALL

SELECT 
    'ADMIN' as tipo,
    pu.nombre || ' ' || pu.apellido as nombre,
    pu.rol as slug,
    'true' as activo
FROM perfiles_usuarios pu 
WHERE pu.restaurante_id = 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f'
AND pu.rol = 'admin';

-- Contar platos por categoría
SELECT 
    cp.nombre as categoria,
    COUNT(p.id) as total_platos,
    COUNT(CASE WHEN p.activo THEN 1 END) as platos_activos
FROM categorias_platos cp
LEFT JOIN platos p ON cp.id = p.categoria_id
WHERE cp.restaurante_id = 'fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f'
GROUP BY cp.nombre, cp.id
ORDER BY cp.nombre;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================
/*
PREREQUISITOS:
1. El usuario admin@lasazoncriolla.com debe existir en auth.users
2. Los scripts de seguridad (secure_legacy_policies.sql) deben ejecutarse primero

DATOS CREADOS:
- 1 perfil de administrador vinculado al restaurante
- 3 categorías de platos (Principales, Bebidas, Postres)  
- 9 platos de ejemplo distribuidos en las categorías
- 1 relación tenant_user con rol super_admin

PRÓXIMOS PASOS:
1. Probar login con admin@lasazoncriolla.com
2. Verificar que puede ver y gestionar platos
3. Probar creación de pedidos
4. Validar RLS con diferentes roles
*/