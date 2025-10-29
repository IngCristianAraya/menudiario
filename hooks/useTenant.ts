import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { createBrowserClient } from '@supabase/ssr';

type TenantConfig = {
  id: string;
  nombre: string;
  subdominio: string;
  configuracion: {
    tema?: string;
    moneda?: string;
    [key: string]: any;
  };
  activo: boolean;
};

export function useTenant() {
  const [tenant, setTenant] = useState<TenantConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const router = useRouter();
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    // Obtener el tenant del contexto del servidor (middleware)
    const tenantId = document.cookie
      .split('; ')
      .find(row => row.startsWith('tenant-id='))
      ?.split('=')[1];

    const fetchTenant = async () => {
      try {
        setLoading(true);
        
        // Si no hay tenant en las cookies, intentar obtenerlo de la URL
        if (!tenantId) {
          const host = window.location.hostname;
          const subdomain = host.split('.')[0];
          
          // Si no hay subdominio, simplemente continuar sin redirección forzada
          if (host === 'localhost') {
            setLoading(false);
            return;
          }
          
          // Obtener el tenant por subdominio
          // 1) Intentar esquema con 'slug' (muchas instancias lo usan)
          const { data: tenantDataSlug, error: tenantErrorSlug } = await supabase
            .from('tenants')
            .select('*')
            .eq('slug', subdomain)
            .eq('is_active', true)
            .single();

          // 2) Intentar esquema en inglés (name, subdomain, is_active, config)
          const { data: tenantDataEn, error: tenantErrorEn } = tenantDataSlug
            ? { data: null as any, error: null as any }
            : await supabase
                .from('tenants')
                .select('*')
                .eq('subdomain', subdomain)
                .eq('is_active', true)
                .single();

          // 3) Si falla, intentar esquema en español (nombre, subdominio, activo, configuracion)
          const tenantData = tenantDataSlug ?? tenantDataEn ?? (await (async () => {
            const { data, error } = await supabase
              .from('tenants')
              .select('*')
              .eq('subdominio', subdomain)
              .eq('activo', true)
              .single();
            if (error) return null;
            return data ?? null;
          })());

          if ((tenantErrorEn && !tenantData) || !tenantData) {
            throw new Error('Tenant no encontrado');
          }

          setTenant({
            id: tenantData.id,
            nombre: (tenantData as any).nombre ?? (tenantData as any).name,
            subdominio: (tenantData as any).subdominio ?? (tenantData as any).subdomain ?? (tenantData as any).slug ?? '',
            configuracion: (tenantData as any).configuracion ?? (tenantData as any).config ?? {},
            activo: (tenantData as any).activo ?? (tenantData as any).is_active
          });
        } else {
          // Obtener el tenant por ID
          const { data: tenantData, error: tenantError } = await supabase
            .from('tenants')
            .select('*')
            .eq('id', tenantId)
            .single();

          if (tenantError || !tenantData) {
            throw new Error('Tenant no encontrado');
          }
          
          setTenant({
            id: tenantData.id,
            nombre: (tenantData as any).nombre ?? (tenantData as any).name,
            subdominio: (tenantData as any).subdominio ?? (tenantData as any).subdomain ?? (tenantData as any).slug ?? '',
            configuracion: (tenantData as any).configuracion ?? (tenantData as any).config ?? {},
            activo: (tenantData as any).activo ?? (tenantData as any).is_active
          });
        }
      } catch (err) {
        console.error('Error al cargar el tenant:', err);
        setError(err instanceof Error ? err : new Error('Error desconocido'));
        // No forzar redirecciones a dominios placeholder; mostrar error/controlar estado
      } finally {
        setLoading(false);
      }
    };

    fetchTenant();
  }, [router.asPath]);

  // Función para cambiar de tenant (útil para el panel de administración)
  const switchTenant = async (tenantId: string) => {
    try {
      setLoading(true);
      
      const { data: tenantData, error } = await supabase
        .from('tenants')
        .select('*')
        .eq('id', tenantId)
        .single();

      if (error || !tenantData) {
        throw new Error('No se pudo cambiar al tenant especificado');
      }

      // Establecer cookie del tenant
      document.cookie = `tenant-id=${tenantId}; path=/; max-age=31536000; samesite=lax`;
      
      // Redirigir al subdominio del tenant si existe dominio raíz configurado
      const rootDomain = process.env.NEXT_PUBLIC_ROOT_DOMAIN;
      const subd = (tenantData as any).subdominio ?? (tenantData as any).subdomain ?? (tenantData as any).slug;
      if (rootDomain && subd) {
        window.location.href = `https://${subd}.${rootDomain}`;
      } else {
        // Fallback: recargar la página actual para aplicar el cambio de cookie
        window.location.href = '/';
      }
      
      return true;
    } catch (err) {
      console.error('Error al cambiar de tenant:', err);
      setError(err instanceof Error ? err : new Error('Error desconocido'));
      return false;
    } finally {
      setLoading(false);
    }
  };

  return {
    tenant,
    loading,
    error,
    switchTenant,
    isAdmin: false, // Se puede implementar lógica de roles si es necesario
  };
}

// Hook para obtener el ID del tenant actual
export function useTenantId(): string | null {
  const [tenantId, setTenantId] = useState<string | null>(null);

  useEffect(() => {
    // Obtener el tenant de las cookies
    const id = document.cookie
      .split('; ')
      .find(row => row.startsWith('tenant-id='))
      ?.split('=')[1] || null;

    setTenantId(id);
  }, []);

  return tenantId;
}

// Hook para obtener la configuración del tenant
export function useTenantConfig() {
  const { tenant, loading, error } = useTenant();
  
  return {
    config: tenant?.configuracion || {},
    loading,
    error,
  };
}
