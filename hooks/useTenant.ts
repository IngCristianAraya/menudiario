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
          
          // Si no hay subdominio, redirigir a la página principal
          if (host === 'tudominio.com' || host === 'localhost') {
            setLoading(false);
            return;
          }
          
          // Obtener el tenant por subdominio
          const { data: tenantData, error: tenantError } = await supabase
            .from('tenants')
            .select('*')
            .eq('subdominio', subdomain)
            .eq('activo', true)
            .single();

          if (tenantError || !tenantData) {
            throw new Error('Tenant no encontrado');
          }
          
          setTenant({
            id: tenantData.id,
            nombre: tenantData.nombre,
            subdominio: tenantData.subdominio,
            configuracion: tenantData.configuracion || {},
            activo: tenantData.activo
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
            nombre: tenantData.nombre,
            subdominio: tenantData.subdominio,
            configuracion: tenantData.configuracion || {},
            activo: tenantData.activo
          });
        }
      } catch (err) {
        console.error('Error al cargar el tenant:', err);
        setError(err instanceof Error ? err : new Error('Error desconocido'));
        // Redirigir a la página principal si hay un error
        if (window.location.hostname !== 'tudominio.com' && window.location.hostname !== 'localhost') {
          window.location.href = 'https://tudominio.com';
        }
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
      
      // Redirigir al subdominio del tenant
      window.location.href = `https://${tenantData.subdominio}.tudominio.com`;
      
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
