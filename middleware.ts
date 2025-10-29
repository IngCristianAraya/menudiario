import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { updateSession } from '@/lib/supabase/middleware';
import { getToken } from 'next-auth/jwt';

// Types
type Tenant = {
  id: string;
  name: string;
  subdomain: string;
  is_active: boolean;
};

type UserTenantAccess = {
  has_access: boolean;
  role: string;
};

declare namespace NodeJS {
  interface ProcessEnv {
    NEXT_PUBLIC_SUPABASE_URL: string;
    NEXT_PUBLIC_SUPABASE_ANON_KEY: string;
    SUPABASE_SERVICE_ROLE_KEY: string;
    NEXTAUTH_SECRET: string;
    DEFAULT_TENANT_ID?: string;
    DEFAULT_TENANT_NAME?: string;
  }
}

// Crear el cliente de Supabase bajo demanda para evitar errores en build/prerender
function getSupabaseAdmin(): any | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !service) {
    // En entorno de build/prerender estas variables pueden no existir; devolvemos null
    return null;
  }
  return createClient(url, service, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  }) as any;
}

// Fallback: buscar tenant directamente en la tabla con diferentes combinaciones de columnas
async function findTenantBySlugOrSubdomain(supabase: any | null, sub: string): Promise<Tenant | null> {
  if (!supabase) return null;
  const combos = [
    { subCol: 'slug', activeCol: 'is_active', nameCol: 'name' },
    { subCol: 'slug', activeCol: 'activo', nameCol: 'nombre' },
    { subCol: 'subdomain', activeCol: 'is_active', nameCol: 'name' },
    { subCol: 'subdominio', activeCol: 'activo', nameCol: 'nombre' },
  ] as const;

  for (const c of combos) {
    const selectCols = `id, ${c.subCol}, ${c.nameCol}, ${c.activeCol}`;
    const { data } = await supabase
      .from('tenants')
      .select(selectCols)
      .eq(c.subCol, sub)
      .maybeSingle();

    const row = data as any;
    if (row && row.id) {
      const isActiveRaw = row[c.activeCol];
      const isActive = typeof isActiveRaw === 'boolean' ? isActiveRaw : Boolean(isActiveRaw ?? true);
      const name = row[c.nameCol] ?? row['name'] ?? 'Tenant';
      const subdomainOrSlug = row[c.subCol] ?? sub;
      return {
        id: row.id as string,
        name,
        subdomain: String(subdomainOrSlug),
        is_active: isActive,
      };
    }
  }
  return null;
}

const publicPaths = [
  '/auth/login',
  '/auth/register',
  '/auth/error',
  '/landing',
];

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const host = request.headers.get('host') || '';
  const isLocalhost = host.includes('localhost');
  const hostParts = host.split('.');
  const isSubdomain = hostParts.length > (isLocalhost ? 1 : 2);
  const subdomain = isSubdomain ? hostParts[0].toLowerCase() : 'default';
  const supabase = getSupabaseAdmin();

  // 1. Ignorar archivos estáticos y rutas de API de autenticación
  if (
    pathname.startsWith('/_next') || 
    pathname.startsWith('/static') || 
    pathname.startsWith('/api/auth') ||
    // Permitir leer configuración de tenant sin autenticación
    pathname.startsWith('/api/tenant/config') ||
    pathname.includes('.')
  ) {
    return NextResponse.next();
  }

  // 2. Manejar rutas públicas
  if (publicPaths.some(path => pathname.startsWith(path))) {
    return NextResponse.next();
  }

  // 2.1 Permitir endpoints de desarrollo en cualquier host cuando no es producción
  if (process.env.NODE_ENV !== 'production' && pathname.startsWith('/api/dev')) {
    return NextResponse.next();
  }

  // 3. Obtener información del tenant
  let skipTenantVerification = false;
  let tenantData: any = null;
  let tenantError: any = null;
  if (supabase) {
    const { data, error } = await supabase
      .rpc('get_tenant_by_subdomain', { 
        p_subdomain: subdomain 
      });
    tenantData = data;
    tenantError = error;
  }
  
  const tenant = tenantData as unknown as Tenant | null;

  const requestHeaders = new Headers(request.headers);

  if (tenantError || !tenant) {
    if (isLocalhost) {
      // Fallback en desarrollo: permitir acceso sin tenant definido
      skipTenantVerification = true;
      const devTenantId = process.env.DEFAULT_TENANT_ID || 'dev-tenant';
      const devTenantName = process.env.DEFAULT_TENANT_NAME || 'Development';
      requestHeaders.set('x-tenant-id', devTenantId);
      requestHeaders.set('x-tenant-schema', `tenant_${devTenantId.replace(/-/g, '_')}`);
      requestHeaders.set('x-tenant-name', devTenantName);
    } else {
      // Fallback adicional: intentar buscar por slug/subdominio directamente
      const fallbackTenant = await findTenantBySlugOrSubdomain(supabase, subdomain);
      if (fallbackTenant && fallbackTenant.is_active) {
        requestHeaders.set('x-tenant-id', fallbackTenant.id);
        requestHeaders.set('x-tenant-schema', `tenant_${fallbackTenant.id.replace(/-/g, '_')}`);
        requestHeaders.set('x-tenant-name', fallbackTenant.name);
      } else {
        console.error('Tenant no encontrado o inactivo:', subdomain);
        const loginUrl = new URL('/auth/login', request.url);
        loginUrl.searchParams.set('error', 'TenantNotFound');
        return NextResponse.redirect(loginUrl);
      }
    }
  } else {
    // 4. Configurar headers del tenant
    requestHeaders.set('x-tenant-id', tenant.id);
    requestHeaders.set('x-tenant-schema', `tenant_${tenant.id.replace(/-/g, '_')}`);
    requestHeaders.set('x-tenant-name', tenant.name);
  }

  // 5. Verificar autenticación para rutas protegidas
  if (pathname.startsWith('/admin') || pathname.startsWith('/api')) {
    const response = NextResponse.next({
      request: { headers: requestHeaders },
    });
    
    // Actualizar la sesión (Supabase)
    let session = await updateSession(request, response);
    let nextAuthToken: any = null;

    // Fallback: intentar con sesión de NextAuth (JWT)
    if (!session) {
      nextAuthToken = await getToken({ req: request, secret: process.env.NEXTAUTH_SECRET });
      if (!nextAuthToken) {
        const loginUrl = new URL('/auth/login', request.url);
        loginUrl.searchParams.set('callbackUrl', pathname);
        loginUrl.searchParams.set('tenant', subdomain);
        return NextResponse.redirect(loginUrl);
      }
    }

    // Verificar acceso al tenant sólo si no estamos en modo dev sin tenant
    const userId = (session?.user?.id as string) || (nextAuthToken?.sub as string) || '';
    if (!skipTenantVerification && tenant?.id) {
      let userTenantData: any = null;
      let accessError: any = null;
      if (supabase) {
        const { data, error } = await supabase
          .rpc('check_user_tenant_access', {
            p_user_id: userId,
            p_tenant_id: tenant.id,
          });
        userTenantData = data;
        accessError = error;
      } else {
        accessError = new Error('Supabase no configurado');
      }
      
      const userTenant = userTenantData as unknown as UserTenantAccess | null;
  
      if (accessError || !userTenant?.has_access) {
        return new NextResponse('Acceso no autorizado', { 
          status: 403,
          headers: {
            'Content-Type': 'text/plain; charset=utf-8',
          },
        });
      }

      // Añadir información del usuario a los headers
      if (userId) {
        requestHeaders.set('x-user-id', userId);
      }
      if (userTenant && 'role' in userTenant) {
        requestHeaders.set('x-user-role', userTenant.role);
      }
    } else {
      // En desarrollo sin tenant, sólo añadimos el user id si existe
      if (userId) {
        requestHeaders.set('x-user-id', userId);
      }
      requestHeaders.set('x-user-role', 'admin');
    }
  }

  // 6. Mantener la raíz pública para la app móvil (sin redirección)
  // Antes se redirigía a /admin/dashboard, lo retiramos para permitir acceso a '/',
  // '/nuevo-pedido' y '/pedidos-hoy' sin forzar login del panel admin.

  // 7. Continuar con la solicitud
  const response = NextResponse.next({
    request: { headers: requestHeaders },
  });

  // Si hay una sesión, actualizarla
  if (pathname.startsWith('/admin')) {
    await updateSession(request, response);
  }

  return response;
}

// Configuración del middleware
export const config = {
  matcher: [
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
