'use client';

import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { createBrowserClient } from '@supabase/ssr';
import { useRouter } from 'next/navigation';

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

type TenantContextType = {
  tenant: TenantConfig | null;
  loading: boolean;
  error: Error | null;
  switchTenant: (tenantId: string) => Promise<boolean>;
  isAdmin: boolean;
};

const TenantContext = createContext<TenantContextType | undefined>(undefined);

export function TenantProvider({ children }: { children: ReactNode }) {
  const [tenant, setTenant] = useState<TenantConfig | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);
  const router = useRouter();
  const supabase = createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );

  useEffect(() => {
    const fetchTenant = async () => {
      try {
        setLoading(true);
        
        // Obtener el tenant del subdominio
        const host = window.location.hostname;
        const hostParts = host.split('.');
        const isSubdomain = hostParts.length > 2 || 
                          (hostParts.length === 2 && !['localhost', '127.0.0.1'].includes(hostParts[0]));
        
        // Si no hay subdominio, no hay tenant
        if (!isSubdomain) {
          setLoading(false);
          return;
        }
        
        const subdomain = hostParts[0];
        
        // Obtener el tenant por subdominio
        const { data: tenantData, error: tenantError } = await supabase
          .from('tenants')
          .select('*')
          .eq('subdominio', subdomain)
          .eq('activo', true)
          .single();

        if (tenantError || !tenantData) {
          throw new Error('Tenant no encontrado o inactivo');
        }
        
        setTenant({
          id: tenantData.id,
          nombre: tenantData.nombre,
          subdominio: tenantData.subdominio,
          configuracion: tenantData.configuracion || {},
          activo: tenantData.activo
        });
        
        // Establecer cookie del tenant
        document.cookie = `tenant-id=${tenantData.id}; path=/; max-age=31536000; samesite=lax`;
        
      } catch (err) {
        console.error('Error al cargar el tenant:', err);
        setError(err instanceof Error ? err : new Error('Error desconocido'));
        
        // No forzar redirecciones a dominios placeholder; mantener al usuario en la app
      } finally {
        setLoading(false);
      }
    };

    fetchTenant();
  }, [router]);

  // Función para cambiar de tenant (útil para el panel de administración)
  const switchTenant = async (tenantId: string): Promise<boolean> => {
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
      if (rootDomain) {
        const protocol = window.location.hostname === 'localhost' ? 'http' : 'https';
        const port = window.location.hostname === 'localhost' ? ':3000' : '';
        window.location.href = `${protocol}://${tenantData.subdominio}.${rootDomain}${port}`;
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

  return (
    <TenantContext.Provider 
      value={{
        tenant,
        loading,
        error,
        switchTenant,
        isAdmin: false, // Se puede implementar lógica de roles si es necesario
      }}
    >
      {children}
    </TenantContext.Provider>
  );
}

export function useTenant() {
  const context = useContext(TenantContext);
  if (context === undefined) {
    throw new Error('useTenant debe ser usado dentro de un TenantProvider');
  }
  return context;
}

// Hook para obtener solo el ID del tenant
export function useTenantId(): string | null {
  const { tenant } = useTenant();
  return tenant?.id || null;
}

// Hook para obtener solo la configuración del tenant
export function useTenantConfig() {
  const { tenant, loading, error } = useTenant();
  
  return {
    config: tenant?.configuracion || {},
    loading,
    error,
  };
}
