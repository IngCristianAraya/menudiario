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

declare module 'next' {
  interface NextApiRequest {
    tenant?: Tenant.Tenant;
    user?: {
      id: string;
      email: string;
      role: string;
    };
  }
}

declare module 'next/headers' {
  interface Headers {
    get(name: 'x-tenant-id'): string | null;
    get(name: 'x-tenant-name'): string | null;
    get(name: 'x-tenant-schema'): string | null;
    get(name: 'x-user-id'): string | null;
    get(name: 'x-user-role'): string | null;
  }
}
