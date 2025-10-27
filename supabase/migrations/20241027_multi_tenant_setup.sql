-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tenants table
CREATE TABLE IF NOT EXISTS public.tenants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    subdomain TEXT NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    config JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create users table (managed by Supabase Auth)
-- This table is created automatically by Supabase Auth
-- We'll create a profiles table to store additional user data

-- Create user profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name TEXT,
    last_name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create tenant_users join table
CREATE TABLE IF NOT EXISTS public.tenant_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('owner', 'admin', 'staff', 'user')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, tenant_id)
);

-- Create function to get tenant by subdomain
CREATE OR REPLACE FUNCTION public.get_tenant_by_subdomain(p_subdomain TEXT)
RETURNS SETOF tenants AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM public.tenants 
    WHERE subdomain = p_subdomain 
    AND is_active = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to check user tenant access
CREATE OR REPLACE FUNCTION public.check_user_tenant_access(
    p_user_id UUID,
    p_tenant_id UUID
)
RETURNS TABLE (
    has_access BOOLEAN,
    role TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        true as has_access,
        tu.role::TEXT
    FROM public.tenant_users tu
    WHERE tu.user_id = p_user_id
    AND tu.tenant_id = p_tenant_id
    LIMIT 1;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to set current tenant context
CREATE OR REPLACE FUNCTION public.set_tenant_context()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM set_config('app.current_tenant_id', NEW.tenant_id::TEXT, true);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_tenants_updated_at
BEFORE UPDATE ON public.tenants
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER update_tenant_users_updated_at
BEFORE UPDATE ON public.tenant_users
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_users ENABLE ROW LEVEL SECURITY;

-- Create policies for tenants table
CREATE POLICY "Enable read access for all users"
ON public.tenants
FOR SELECT
USING (true);

CREATE POLICY "Enable insert for authenticated users"
ON public.tenants
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Create policies for profiles table
CREATE POLICY "Users can view their own profile"
ON public.profiles
FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
ON public.profiles
FOR UPDATE
USING (auth.uid() = id);

-- Create policies for tenant_users table
CREATE POLICY "Users can view their own tenant memberships"
ON public.tenant_users
FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Tenant admins can manage their tenant's users"
ON public.tenant_users
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM public.tenant_users tu
        WHERE tu.user_id = auth.uid()
        AND tu.tenant_id = tenant_users.tenant_id
        AND tu.role IN ('owner', 'admin')
    )
);

-- Create a default tenant for development
INSERT INTO public.tenants (name, subdomain, is_active)
VALUES ('Default Tenant', 'default', true)
ON CONFLICT (subdomain) DO NOTHING;

-- Create a function to create a new tenant with an admin user
CREATE OR REPLACE FUNCTION public.create_tenant_with_admin(
    p_tenant_name TEXT,
    p_subdomain TEXT,
    p_admin_email TEXT,
    p_admin_password TEXT
)
RETURNS UUID AS $$
DECLARE
    v_tenant_id UUID;
    v_user_id UUID;
BEGIN
    -- Create tenant
    INSERT INTO public.tenants (name, subdomain, is_active)
    VALUES (p_tenant_name, p_subdomain, true)
    RETURNING id INTO v_tenant_id;
    
    -- Create user (this would be handled by Supabase Auth in the app)
    -- For migration purposes, we'll just create a reference
    -- In a real app, you would use Supabase Auth to create the user
    
    -- Add user to tenant as owner
    -- This would be done after the user is created in your application code
    
    RETURN v_tenant_id;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Error creating tenant: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to get the current user's tenants
CREATE OR REPLACE FUNCTION public.get_user_tenants()
RETURNS TABLE (
    id UUID,
    name TEXT,
    subdomain TEXT,
    role TEXT,
    is_active BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        t.id,
        t.name,
        t.subdomain,
        tu.role,
        t.is_active
    FROM public.tenants t
    JOIN public.tenant_users tu ON t.id = tu.tenant_id
    WHERE tu.user_id = auth.uid()
    ORDER BY t.created_at DESC;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Create a function to check if a user is a tenant admin
CREATE OR REPLACE FUNCTION public.is_tenant_admin(p_tenant_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 
        FROM public.tenant_users
        WHERE user_id = auth.uid()
        AND tenant_id = p_tenant_id
        AND role IN ('owner', 'admin')
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
