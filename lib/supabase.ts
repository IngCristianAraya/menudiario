import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

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
