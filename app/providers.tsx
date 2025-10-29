'use client';

import { createBrowserClient } from '@supabase/ssr';
import { SessionContextProvider } from '@supabase/auth-helpers-react';
import { TenantProvider } from '@/contexts/TenantContext';
import { useState } from 'react';

export function Providers({ children }: { children: React.ReactNode }) {
  // Inicialización perezosa del cliente Supabase para evitar ERR_INVALID_URL durante prerenderizado
  const [supabase] = useState(() => {
    // Solo crear el cliente si estamos en el navegador y las variables están disponibles
    if (typeof window === 'undefined') return null;
    
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    
    if (!url || !key) {
      console.warn('Supabase environment variables not found');
      return null;
    }
    
    return createBrowserClient(url, key);
  });

  // Si no hay cliente (durante SSR), renderizar sin SessionContextProvider
  if (!supabase) {
    return (
      <TenantProvider>
        {children}
      </TenantProvider>
    );
  }

  return (
    <SessionContextProvider supabaseClient={supabase}>
      <TenantProvider>
        {children}
      </TenantProvider>
    </SessionContextProvider>
  );
}
