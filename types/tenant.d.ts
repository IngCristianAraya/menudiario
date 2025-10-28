// Tenant types
declare namespace Tenant {
  interface Tenant {
    id: string;
    name: string;
    subdomain: string;
    is_active: boolean;
    created_at: string;
    updated_at: string;
  }

  interface UserTenantAccess {
    has_access: boolean;
    role: 'admin' | 'staff' | 'user';
  }

  interface UserProfile {
    id: string;
    user_id: string;
    tenant_id: string;
    role: 'admin' | 'staff' | 'user';
    created_at: string;
    updated_at: string;
  }
}

// Nota: Las rutas usan Request/NextResponse del App Router; no es necesario
// sobrescribir tipos del módulo 'next' ni de 'next/headers'.
