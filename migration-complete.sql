-- =====================================================
-- MIGRACIÓN COMPLETA PARA RLS - SISTEMA DE PEDIDOS
-- =====================================================
-- Ejecutar este archivo completo en el SQL Editor de Supabase

-- 1. Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Crear tipos de datos
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'user_role'
  ) THEN
    CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'staff', 'customer');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'estado_pedido'
  ) THEN
    CREATE TYPE estado_pedido AS ENUM ('pendiente', 'en_preparacion', 'listo', 'entregado', 'cancelado');
  END IF;
END $$;

-- 3. Tabla restaurantes (principal para multi-tenancy)
CREATE TABLE IF NOT EXISTS public.restaurantes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre TEXT NOT NULL,
    email TEXT,
    telefono TEXT,
    direccion TEXT,
    logo_url TEXT,
    horario TEXT,
    configuracion JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Añadir columnas de soporte para multi-dominio si no existen
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'restaurantes' AND column_name = 'slug'
    ) THEN
        ALTER TABLE public.restaurantes ADD COLUMN slug TEXT UNIQUE;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'restaurantes' AND column_name = 'activo'
    ) THEN
        ALTER TABLE public.restaurantes ADD COLUMN activo BOOLEAN DEFAULT true;
    END IF;
END $$;

-- 4. Tabla perfiles_usuarios (extensión de auth.users)
CREATE TABLE IF NOT EXISTS public.perfiles_usuarios (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    restaurante_id UUID REFERENCES public.restaurantes ON DELETE CASCADE,
    nombre TEXT,
    apellido TEXT,
    avatar_url TEXT,
    rol user_role NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Tabla platos
CREATE TABLE IF NOT EXISTS public.platos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    imagen_url TEXT,
    categoria_id UUID,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Tabla pedidos
CREATE TABLE IF NOT EXISTS public.pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes ON DELETE CASCADE,
    cliente_id UUID REFERENCES auth.users ON DELETE SET NULL,
    codigo_pedido VARCHAR(10) UNIQUE NOT NULL,
    estado estado_pedido NOT NULL DEFAULT 'pendiente',
    tipo_entrega TEXT NOT NULL CHECK (tipo_entrega IN ('mesa', 'domicilio', 'recojo')),
    detalles_entrega JSONB,
    total NUMERIC(10,2) NOT NULL,
    fecha_pedido TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. Tabla items_pedido
CREATE TABLE IF NOT EXISTS public.items_pedido (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID REFERENCES public.pedidos(id) ON DELETE CASCADE,
    plato_id UUID REFERENCES public.platos(id),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL,
    notas TEXT,
    estado estado_pedido NOT NULL DEFAULT 'pendiente',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. Función para generar códigos de pedido únicos
CREATE OR REPLACE FUNCTION generate_codigo_pedido()
RETURNS TEXT AS $$
DECLARE
    codigo TEXT;
    existe BOOLEAN;
BEGIN
    LOOP
        codigo := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        SELECT EXISTS(SELECT 1 FROM pedidos WHERE codigo_pedido = codigo) INTO existe;
        EXIT WHEN NOT existe;
    END LOOP;
    RETURN codigo;
END;
$$ LANGUAGE plpgsql;

-- 9. Trigger para generar código automáticamente
CREATE OR REPLACE FUNCTION set_codigo_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.codigo_pedido IS NULL OR NEW.codigo_pedido = '' THEN
        NEW.codigo_pedido := generate_codigo_pedido();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_codigo_pedido ON pedidos;
CREATE TRIGGER trigger_set_codigo_pedido
    BEFORE INSERT ON pedidos
    FOR EACH ROW
EXECUTE FUNCTION set_codigo_pedido();

-- 10. RPC: obtener user_id de auth.users por email (solo Service Role)
-- Permite recuperar el UUID del usuario cuando el Admin API falla.
CREATE OR REPLACE FUNCTION public.get_auth_user_id_by_email(p_email TEXT)
RETURNS UUID AS $func$
DECLARE
    claims JSONB := current_setting('request.jwt.claims', true)::jsonb;
    result UUID;
BEGIN
    IF claims->>'role' IS DISTINCT FROM 'service_role' THEN
        RAISE EXCEPTION 'Acceso restringido: solo Service Role';
    END IF;

    SELECT u.id INTO result
    FROM auth.users u
    WHERE u.email = p_email
    LIMIT 1;

    RETURN result;
END;
$func$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- APLICAR RLS (Row Level Security)
-- =====================================================

-- 1. Habilitar RLS en todas las tablas
ALTER TABLE public.perfiles_usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.items_pedido ENABLE ROW LEVEL SECURITY;

-- 2. Políticas para perfiles_usuarios
DROP POLICY IF EXISTS "perfiles_select_own_restaurant" ON public.perfiles_usuarios;
CREATE POLICY "perfiles_select_own_restaurant" ON public.perfiles_usuarios
    FOR SELECT USING (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "perfiles_insert_own_restaurant" ON public.perfiles_usuarios;
CREATE POLICY "perfiles_insert_own_restaurant" ON public.perfiles_usuarios
    FOR INSERT WITH CHECK (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        ) OR 
        auth.uid() IS NULL -- Permitir inserción durante registro
    );

DROP POLICY IF EXISTS "perfiles_update_own_restaurant" ON public.perfiles_usuarios;
CREATE POLICY "perfiles_update_own_restaurant" ON public.perfiles_usuarios
    FOR UPDATE USING (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        )
    );

-- 3. Políticas para restaurantes
DROP POLICY IF EXISTS "restaurantes_select_own" ON public.restaurantes;
CREATE POLICY "restaurantes_select_own" ON public.restaurantes
    FOR SELECT USING (
        id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        ) OR 
        auth.uid() IS NULL -- Permitir acceso público para registro
    );

DROP POLICY IF EXISTS "restaurantes_insert_public" ON public.restaurantes;
CREATE POLICY "restaurantes_insert_public" ON public.restaurantes
    FOR INSERT WITH CHECK (true); -- Permitir inserción pública para registro

DROP POLICY IF EXISTS "restaurantes_update_own" ON public.restaurantes;
CREATE POLICY "restaurantes_update_own" ON public.restaurantes
    FOR UPDATE USING (
        id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        )
    );

-- 4. Políticas para platos
DROP POLICY IF EXISTS "platos_select_same_restaurant" ON public.platos;
CREATE POLICY "platos_select_same_restaurant" ON public.platos
    FOR SELECT USING (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        ) OR 
        auth.uid() IS NULL -- Permitir acceso público para clientes
    );

DROP POLICY IF EXISTS "platos_write_admin" ON public.platos;
CREATE POLICY "platos_write_admin" ON public.platos
    FOR ALL USING (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid() AND rol IN ('admin', 'super_admin')
        )
    ) WITH CHECK (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid() AND rol IN ('admin', 'super_admin')
        )
    );

-- Vista de compatibilidad para frontend multi-tenant basado en 'tenants'
-- Si ya existe una TABLA llamada 'tenants', no se puede reemplazar por una vista.
-- En ese caso, se crea una vista alternativa 'tenants_view'.
DO $do$
DECLARE
    tenants_kind CHAR;
BEGIN
    SELECT c.relkind INTO tenants_kind
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'tenants' AND n.nspname = 'public';

    IF tenants_kind IS NULL THEN
        -- No existe 'tenants': crear la vista con ese nombre
        EXECUTE $v$
        CREATE VIEW public.tenants AS
        SELECT 
            r.id,
            r.nombre,
            r.slug AS subdominio,
            r.configuracion,
            COALESCE(r.activo, true) AS activo
        FROM public.restaurantes r;
        $v$;
    ELSIF tenants_kind = 'v' THEN
        -- Ya es una vista: reemplazarla
        EXECUTE $v$
        CREATE OR REPLACE VIEW public.tenants AS
        SELECT 
            r.id,
            r.nombre,
            r.slug AS subdominio,
            r.configuracion,
            COALESCE(r.activo, true) AS activo
        FROM public.restaurantes r;
        $v$;
    ELSE
        -- Existe como tabla/materialized view: crear vista alternativa
        IF to_regclass('public.tenants_view') IS NULL THEN
            EXECUTE $v$
            CREATE VIEW public.tenants_view AS
            SELECT 
                r.id,
                r.nombre,
                r.slug AS subdominio,
                r.configuracion,
                COALESCE(r.activo, true) AS activo
            FROM public.restaurantes r;
            $v$;
        END IF;
    END IF;
END $do$;

-- 5. Políticas para pedidos
DROP POLICY IF EXISTS "pedidos_select_same_restaurant" ON public.pedidos;
CREATE POLICY "pedidos_select_same_restaurant" ON public.pedidos
    FOR SELECT USING (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        ) OR 
        cliente_id = auth.uid() OR
        auth.uid() IS NULL -- Permitir acceso público temporal
    );

DROP POLICY IF EXISTS "pedidos_insert_same_restaurant" ON public.pedidos;
CREATE POLICY "pedidos_insert_same_restaurant" ON public.pedidos
    FOR INSERT WITH CHECK (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        ) OR 
        auth.uid() IS NULL -- Permitir inserción pública para clientes
    );

DROP POLICY IF EXISTS "pedidos_update_same_restaurant" ON public.pedidos;
CREATE POLICY "pedidos_update_same_restaurant" ON public.pedidos
    FOR UPDATE USING (
        restaurante_id = (
            SELECT restaurante_id FROM public.perfiles_usuarios 
            WHERE id = auth.uid()
        )
    );

-- 6. Políticas para items_pedido
DROP POLICY IF EXISTS "items_select_same_restaurant" ON public.items_pedido;
CREATE POLICY "items_select_same_restaurant" ON public.items_pedido
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.pedidos p 
            WHERE p.id = pedido_id 
            AND (
                p.restaurante_id = (
                    SELECT restaurante_id FROM public.perfiles_usuarios 
                    WHERE id = auth.uid()
                ) OR 
                p.cliente_id = auth.uid() OR
                auth.uid() IS NULL
            )
        )
    );

DROP POLICY IF EXISTS "items_write_same_restaurant" ON public.items_pedido;
CREATE POLICY "items_write_same_restaurant" ON public.items_pedido
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.pedidos p 
            WHERE p.id = pedido_id 
            AND (
                p.restaurante_id = (
                    SELECT restaurante_id FROM public.perfiles_usuarios 
                    WHERE id = auth.uid()
                ) OR 
                auth.uid() IS NULL
            )
        )
    );

-- =====================================================
-- POLÍTICAS PARA TABLAS OPCIONALES (si existen)
-- =====================================================

-- Verificar y aplicar RLS a menus_diarios si existe
DO $$
BEGIN
    IF to_regclass('public.menus_diarios') IS NOT NULL THEN
        -- Agregar columna restaurante_id si no existe
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'menus_diarios' 
            AND column_name = 'restaurante_id'
        ) THEN
            ALTER TABLE public.menus_diarios 
            ADD COLUMN restaurante_id UUID REFERENCES public.restaurantes(id);
        END IF;
        
        -- Habilitar RLS
        ALTER TABLE public.menus_diarios ENABLE ROW LEVEL SECURITY;
        
        -- Políticas
        DROP POLICY IF EXISTS "menus_select_same_rest" ON public.menus_diarios;
        CREATE POLICY "menus_select_same_rest" ON public.menus_diarios
            FOR SELECT USING (
                restaurante_id = (
                    SELECT restaurante_id FROM public.perfiles_usuarios 
                    WHERE id = auth.uid()
                ) OR auth.uid() IS NULL
            );
            
        DROP POLICY IF EXISTS "menus_write_admin" ON public.menus_diarios;
        CREATE POLICY "menus_write_admin" ON public.menus_diarios
            FOR ALL USING (
                restaurante_id = (
                    SELECT restaurante_id FROM public.perfiles_usuarios 
                    WHERE id = auth.uid() AND rol IN ('admin', 'super_admin')
                ) OR auth.uid() IS NULL
            );
    END IF;
END $$;

-- Verificar y aplicar RLS a pedidos_diarios si existe
DO $$
BEGIN
    IF to_regclass('public.pedidos_diarios') IS NOT NULL THEN
        -- Agregar columna restaurante_id si no existe
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'pedidos_diarios' 
            AND column_name = 'restaurante_id'
        ) THEN
            ALTER TABLE public.pedidos_diarios 
            ADD COLUMN restaurante_id UUID REFERENCES public.restaurantes(id);
        END IF;
        
        -- Habilitar RLS
        ALTER TABLE public.pedidos_diarios ENABLE ROW LEVEL SECURITY;
        
        -- Políticas
        DROP POLICY IF EXISTS "pd_select_same_rest" ON public.pedidos_diarios;
        CREATE POLICY "pd_select_same_rest" ON public.pedidos_diarios
            FOR SELECT USING (
                restaurante_id = (
                    SELECT restaurante_id FROM public.perfiles_usuarios 
                    WHERE id = auth.uid()
                ) OR auth.uid() IS NULL
            );
            
        DROP POLICY IF EXISTS "pd_write_same_rest" ON public.pedidos_diarios;
        CREATE POLICY "pd_write_same_rest" ON public.pedidos_diarios
            FOR ALL USING (
                restaurante_id = (
                    SELECT restaurante_id FROM public.perfiles_usuarios 
                    WHERE id = auth.uid()
                ) OR auth.uid() IS NULL
            );
    END IF;
END $$;

-- =====================================================
-- VERIFICACIÓN FINAL
-- =====================================================

-- Mostrar estado de RLS en todas las tablas
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('restaurantes', 'perfiles_usuarios', 'platos', 'pedidos', 'items_pedido', 'menus_diarios', 'pedidos_diarios')
ORDER BY tablename;