-- =============================================
-- Estructura Multi-Tenant para Sistema de Pedidos
-- =============================================

-- 1. Tabla de Clientes (Tenants)
CREATE TABLE IF NOT EXISTS tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    subdominio TEXT UNIQUE NOT NULL,
    configuracion JSONB DEFAULT '{}'::jsonb,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Tabla de Planes de Suscripción
CREATE TABLE IF NOT EXISTS planes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio_mensual DECIMAL(10,2) NOT NULL,
    max_usuarios INT NOT NULL,
    max_almacenamiento_mb INT NOT NULL,
    caracteristicas JSONB DEFAULT '{}'::jsonb,
    es_publico BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabla de Suscripciones
CREATE TABLE IF NOT EXISTS suscripciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES planes(id),
    estado TEXT NOT NULL CHECK (estado IN ('activa', 'cancelada', 'suspendida', 'en_prueba')),
    fecha_inicio TIMESTAMPTZ NOT NULL,
    fecha_vencimiento TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Modificar tablas existentes para soportar multi-tenancy
-- Nota: Estas sentencias asumen que las tablas ya existen

-- Función para actualizar automáticamente el campo updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Añadir tenant_id a las tablas existentes
DO $$
BEGIN
    -- Añadir tenant_id a restaurantes si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'restaurantes' AND column_name = 'tenant_id') THEN
        ALTER TABLE restaurantes ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
    
    -- Añadir tenant_id a perfiles_usuarios si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'perfiles_usuarios' AND column_name = 'tenant_id') THEN
        ALTER TABLE perfiles_usuarios ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
    
    -- Añadir tenant_id a categorias_platos si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'categorias_platos' AND column_name = 'tenant_id') THEN
        ALTER TABLE categorias_platos ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
    
    -- Añadir tenant_id a platos si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'platos' AND column_name = 'tenant_id') THEN
        ALTER TABLE platos ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
    
    -- Añadir tenant_id a pedidos si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'pedidos' AND column_name = 'tenant_id') THEN
        ALTER TABLE pedidos ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
    
    -- Añadir tenant_id a items_pedido si no existe
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                  WHERE table_name = 'items_pedido' AND column_name = 'tenant_id') THEN
        ALTER TABLE items_pedido ADD COLUMN tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE;
    END IF;
END $$;

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_restaurantes_tenant ON restaurantes(tenant_id);
CREATE INDEX IF NOT EXISTS idx_perfiles_tenant ON perfiles_usuarios(tenant_id);
CREATE INDEX IF NOT EXISTS idx_categorias_tenant ON categorias_platos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_platos_tenant ON platos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_tenant ON pedidos(tenant_id);
CREATE INDEX IF NOT EXISTS idx_items_pedido_tenant ON items_pedido(tenant_id);

-- Actualizar políticas RLS para incluir multi-tenancy
-- Nota: Estas son políticas de ejemplo que deben adaptarse a tu lógica de negocio

-- Política para restaurantes
CREATE OR REPLACE POLICY "Los usuarios solo pueden ver restaurantes de su tenant"
ON restaurantes FOR ALL
USING (tenant_id = (SELECT tenant_id FROM perfiles_usuarios WHERE id = auth.uid()));

-- Política para perfiles de usuario
CREATE OR REPLACE POLICY "Los usuarios solo pueden ver perfiles de su tenant"
ON perfiles_usuarios FOR ALL
USING (tenant_id = (SELECT tenant_id FROM perfiles_usuarios WHERE id = auth.uid()));

-- Función para obtener el tenant_id del usuario actual
CREATE OR REPLACE FUNCTION get_current_tenant_id()
RETURNS UUID AS $$
BEGIN
    RETURN (SELECT tenant_id FROM perfiles_usuarios WHERE id = auth.uid() LIMIT 1);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Insertar datos iniciales de prueba
-- NOTA: Solo para desarrollo, eliminar en producción
INSERT INTO public.tenants (nombre, subdominio, configuracion, activo)
VALUES 
    ('Restaurante de Prueba', 'demo', '{"tema": "claro", "moneda": "USD"}', true),
    ('Otro Restaurante', 'otro', '{"tema": "oscuro", "moneda": "EUR"}', true)
ON CONFLICT (subdominio) DO NOTHING;

-- Insertar planes de ejemplo
INSERT INTO public.planes (nombre, descripcion, precio_mensual, max_usuarios, max_almacenamiento_mb, caracteristicas, es_publico)
VALUES 
    ('Básico', 'Ideal para pequeños negocios', 29.99, 5, 1024, '{"soporte": "email", "backup": "diario"}', true),
    ('Profesional', 'Para restaurantes en crecimiento', 99.99, 20, 5120, '{"soporte": "prioritario", "backup": "cada 6 horas"}', true),
    ('Empresarial', 'Solución completa para cadenas', 299.99, 100, 20480, '{"soporte": "24/7", "backup": "en tiempo real"}', true)
ON CONFLICT (nombre) DO NOTHING;

-- Crear trigger para actualizar automáticamente updated_at
DO $$
BEGIN
    -- Crear triggers para actualizar automáticamente updated_at
    -- Solo si no existen ya
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_tenants_updated_at') THEN
        CREATE TRIGGER update_tenants_updated_at
        BEFORE UPDATE ON tenants
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'update_suscripciones_updated_at') THEN
        CREATE TRIGGER update_suscripciones_updated_at
        BEFORE UPDATE ON suscripciones
        FOR EACH ROW
        EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;
