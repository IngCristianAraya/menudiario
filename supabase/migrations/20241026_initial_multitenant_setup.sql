-- 1. Habilitar la extensión UUID si no está habilitada
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Crear tipo para roles de usuario
CREATE TYPE user_role AS ENUM ('super_admin', 'admin', 'staff', 'customer');

-- 3. Tabla de tenants (restaurantes)
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    logo_url TEXT,
    contact_email TEXT NOT NULL,
    contact_phone TEXT,
    address JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 4. Tabla de usuarios (extensión de auth.users de Supabase)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Tabla de relación usuario-tenant (para multi-tenancy)
CREATE TABLE IF NOT EXISTS public.tenant_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users ON DELETE CASCADE,
    tenant_id UUID REFERENCES public.tenants ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, tenant_id)
);

-- 6. Tabla de categorías de menú
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 7. Tabla de productos
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants ON DELETE CASCADE,
    category_id UUID REFERENCES public.categories ON DELETE SET NULL,
    name TEXT NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    image_url TEXT,
    is_available BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 8. Tabla de órdenes
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'pending', -- pending, confirmed, preparing, ready, delivered, cancelled
    customer_name TEXT,
    customer_phone TEXT,
    customer_email TEXT,
    delivery_address JSONB,
    subtotal DECIMAL(10, 2) NOT NULL,
    tax_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    delivery_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- 9. Tabla de ítems de órdenes
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES public.orders ON DELETE CASCADE,
    product_id UUID REFERENCES public.products ON DELETE SET NULL,
    product_name TEXT NOT NULL,
    product_price DECIMAL(10, 2) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 10. Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_tenant_users_user_id ON public.tenant_users(user_id);
CREATE INDEX IF NOT EXISTS idx_tenant_users_tenant_id ON public.tenant_users(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON public.products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_orders_tenant_id ON public.orders(tenant_id);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);

-- 11. Función para obtener el tenant actual
CREATE OR REPLACE FUNCTION public.get_current_tenant_id()
RETURNS UUID AS $$
DECLARE
    tenant_id UUID;
BEGIN
    SELECT tu.tenant_id INTO tenant_id
    FROM public.tenant_users tu
    WHERE tu.user_id = auth.uid()
    LIMIT 1;
    
    RETURN tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Función para verificar si el usuario es administrador del tenant
CREATE OR REPLACE FUNCTION public.is_tenant_admin(user_id_param UUID, tenant_id_param UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.tenant_users 
        WHERE user_id = user_id_param 
        AND tenant_id = tenant_id_param 
        AND role IN ('admin', 'super_admin')
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Habilitar RLS en todas las tablas
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- 14. Políticas para la tabla de tenants
-- Super administradores pueden ver todos los tenants
CREATE POLICY "Super admins can view all tenants" 
ON public.tenants
FOR SELECT 
TO authenticated
USING (EXISTS (
    SELECT 1 FROM public.tenant_users 
    WHERE user_id = auth.uid() 
    AND role = 'super_admin'
));

-- 15. Políticas para la tabla de perfiles
-- Usuarios pueden ver solo su propio perfil
CREATE POLICY "Users can view their own profile" 
ON public.profiles
FOR SELECT 
TO authenticated
USING (auth.uid() = id);

-- Usuarios pueden actualizar su propio perfil
CREATE POLICY "Users can update their own profile" 
ON public.profiles
FOR UPDATE 
TO authenticated
USING (auth.uid() = id);

-- 16. Políticas para tenant_users
-- Usuarios pueden ver su membresía a tenants
CREATE POLICY "Users can view their tenant memberships" 
ON public.tenant_users
FOR SELECT 
TO authenticated
USING (user_id = auth.uid());

-- Administradores pueden ver miembros de sus tenants
CREATE POLICY "Admins can view tenant members" 
ON public.tenant_users
FOR SELECT 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users tu
        WHERE tu.user_id = auth.uid()
        AND tu.tenant_id = tenant_users.tenant_id
        AND tu.role IN ('admin', 'super_admin')
    )
);

-- 17. Políticas para categorías
-- Usuarios pueden ver categorías de sus tenants
CREATE POLICY "Users can view categories from their tenants" 
ON public.categories
FOR SELECT 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = auth.uid()
        AND tenant_id = categories.tenant_id
    )
);

-- Administradores pueden gestionar categorías de sus tenants
CREATE POLICY "Admins can manage categories in their tenants" 
ON public.categories
FOR ALL 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = auth.uid()
        AND tenant_id = categories.tenant_id
        AND role IN ('admin', 'super_admin')
    )
);

-- 18. Políticas para productos
-- Usuarios pueden ver productos de sus tenants
CREATE POLICY "Users can view products from their tenants" 
ON public.products
FOR SELECT 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = auth.uid()
        AND tenant_id = products.tenant_id
    )
);

-- Administradores pueden gestionar productos de sus tenants
CREATE POLICY "Admins can manage products in their tenants" 
ON public.products
FOR ALL 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = auth.uid()
        AND tenant_id = products.tenant_id
        AND role IN ('admin', 'super_admin')
    )
);

-- 19. Políticas para órdenes
-- Clientes pueden ver sus propias órdenes
CREATE POLICY "Customers can view their own orders" 
ON public.orders
FOR SELECT 
TO authenticated
USING (user_id = auth.uid());

-- Staff puede ver todas las órdenes de su tenant
CREATE POLICY "Staff can view all orders in their tenant" 
ON public.orders
FOR SELECT 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users
        WHERE user_id = auth.uid()
        AND tenant_id = orders.tenant_id
        AND role IN ('staff', 'admin', 'super_admin')
    )
);

-- 20. Crear trigger para actualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar el trigger a las tablas necesarias
DO $$
DECLARE
    t text;
BEGIN
    FOR t IN 
        SELECT table_name 
        FROM information_schema.columns 
        WHERE column_name = 'updated_at' 
        AND table_schema = 'public'
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS update_%s_updated_at ON %I', t, t);
        EXECUTE format('CREATE TRIGGER update_%s_updated_at 
                        BEFORE UPDATE ON %I 
                        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column()', 
                      t, t);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 21. Crear tenant por defecto (opcional)
-- INSERT INTO public.tenants (name, slug, contact_email) 
-- VALUES ('Restaurante de Prueba', 'restaurante-prueba', 'admin@ejemplo.com')
-- ON CONFLICT DO NOTHING;

-- 22. Crear usuario administrador (ejecutar manualmente después de crear el primer usuario)
-- INSERT INTO public.tenant_users (user_id, tenant_id, role)
-- SELECT auth.uid(), id, 'super_admin'
-- FROM public.tenants
-- WHERE slug = 'restaurante-prueba'
-- ON CONFLICT DO NOTHING;
