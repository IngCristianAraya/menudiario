import { createClient } from '@supabase/supabase-js';

// Nota: no crear el cliente en ámbito de módulo para evitar fallos en build
// cuando faltan variables de entorno. Usar fábrica perezosa en cliente.
let browserClient: ReturnType<typeof createClient> | null = null;

export function getSupabaseBrowserClient() {
  if (typeof window === 'undefined') {
    throw new Error('getSupabaseBrowserClient sólo puede usarse en el navegador');
  }
  if (!browserClient) {
    const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    if (!url || !anon) {
      throw new Error('Faltan NEXT_PUBLIC_SUPABASE_URL o NEXT_PUBLIC_SUPABASE_ANON_KEY');
    }
    browserClient = createClient(url, anon);
  }
  return browserClient;
}

export type Categoria = 'entrada' | 'segundo' | 'bebida';

export type MenuItem = {
  id: string;
  nombre: string;
  precio: number;
  categoria: Categoria;
  activo: boolean;
  created_at: string;
  es_obligatorio?: boolean;
};

export type PedidoItem = {
  plato_id: string;
  nombre: string;
  cantidad: number;
  precio: number;
};

export type Pedido = {
  id: string;
  tipo: 'local' | 'delivery';
  items: PedidoItem[];
  total: number;
  fecha: string;
  hora: string;
  cantidad: number;
  created_at: string;
  estado: 'pendiente' | 'preparacion' | 'listo' | 'entregado' | 'cancelado';
  observaciones?: string;
};

export type ResumenDiario = {
  total_pedidos: number;
  total_ventas: number;
  pedidos_local: number;
  pedidos_delivery: number;
};
