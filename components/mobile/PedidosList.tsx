'use client';

import { useEffect, useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Store, Truck, Clock, Trash2 } from 'lucide-react';

// Definición local de la interfaz Pedido
type Pedido = {
  id: string;
  tipo: string;
  items: Array<{
    plato_id: string;
    nombre: string;
    precio: number;
    categoria: string;
    cantidad: number; // Añadido para manejar la cantidad por ítem
  }>;
  total: number;
  fecha: string;
  hora: string;
  cantidad: number;
  created_at: string;
  estado: string;
};

export default function PedidosList() {
  const [pedidos, setPedidos] = useState<Pedido[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadPedidos();
  }, []);

  const loadPedidos = async () => {
    try {
      // Cargar datos de mockup
      const hoy = new Date().toISOString().split('T')[0];
      const mockPedidos = JSON.parse(localStorage.getItem('mockPedidos') || '[]');
      const pedidosHoy = mockPedidos.filter((p: any) => p.fecha === hoy);
      
      // Ordenar por fecha de creación (más reciente primero)
      pedidosHoy.sort((a: any, b: any) => 
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
      
      setPedidos(pedidosHoy as Pedido[]);
      setLoading(false);
      return; // Usando solo localStorage para el modo demo

      /* Código de Supabase comentado - Para habilitar:
      1. Configurar las variables de entorno en Vercel
      2. Descomentar este bloque

      const { data, error } = await supabase
        .from('pedidos_diarios')
        .select('*')
        .eq('fecha', hoy)
        .order('created_at', { ascending: false });

      if (error) throw error;
      
      if (data && Array.isArray(data)) {
        setPedidos(data as Pedido[]);
      } else {
        setPedidos([]);
      }
      */
    } catch (error) {
      console.error('Error loading pedidos:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('¿Eliminar este pedido?')) return;

    try {
      // Eliminar de mockup
      const mockPedidos = JSON.parse(localStorage.getItem('mockPedidos') || '[]');
      const nuevosPedidos = mockPedidos.filter((p: any) => p.id !== id);
      localStorage.setItem('mockPedidos', JSON.stringify(nuevosPedidos));
      
      // Actualizar estado
      setPedidos(prev => prev.filter(p => p.id !== id));
      
      // Mostrar mensaje de éxito
      alert('Pedido eliminado correctamente');
      
      // Recargar la página para actualizar los contadores
      window.location.reload();
      
      return; // Usando solo localStorage para el modo demo
      
      /* Código de Supabase comentado - Para habilitar:
      1. Configurar las variables de entorno en Vercel
      2. Descomentar este bloque
      
      const { error } = await supabase
        .from('pedidos_diarios')
        .delete()
        .eq('id', id);

      if (error) throw error;

      setPedidos((prev) => prev.filter((p) => p.id !== id));
      */
    } catch (error) {
      console.error('Error deleting pedido:', error);
      alert('Error al eliminar el pedido');
    }
  };

  if (loading) {
    return (
      <div className="max-w-[430px] mx-auto px-4 py-6">
        <div className="space-y-3">
          {[...Array(5)].map((_, i) => (
            <div key={i} className="bg-gray-100 rounded-2xl p-4 h-32 animate-pulse" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="max-w-[430px] mx-auto px-4 py-6 safe-top">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.4 }}
        className="mb-6"
      >
        <h1 className="text-2xl font-bold text-gray-900 mb-2">
          Pedidos de Hoy
        </h1>
        <p className="text-sm text-gray-600">
          {pedidos.length} pedido{pedidos.length !== 1 ? 's' : ''} registrado{pedidos.length !== 1 ? 's' : ''}
        </p>
      </motion.div>

      {pedidos.length === 0 ? (
        <motion.div
          initial={{ opacity: 0, scale: 0.9 }}
          animate={{ opacity: 1, scale: 1 }}
          className="bg-white rounded-2xl p-8 text-center shadow-sm border border-gray-100"
        >
          <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Store className="w-8 h-8 text-gray-400" />
          </div>
          <p className="text-gray-600 mb-2">No hay pedidos registrados</p>
          <p className="text-sm text-gray-500">
            Los pedidos que registres aparecerán aquí
          </p>
        </motion.div>
      ) : (
        <div className="space-y-3">
          <AnimatePresence mode="popLayout">
            {pedidos.map((pedido, index) => {
              const Icon = pedido.tipo === 'local' ? Store : Truck;
              const bgColor = pedido.tipo === 'local' ? 'bg-green-50' : 'bg-blue-50';
              const iconColor = pedido.tipo === 'local' ? 'text-green-600' : 'text-blue-600';
              const borderColor = pedido.tipo === 'local' ? 'border-green-100' : 'border-blue-100';

              return (
                <motion.div
                  key={pedido.id}
                  layout
                  initial={{ opacity: 0, y: 20 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, x: -100 }}
                  transition={{ delay: index * 0.05, duration: 0.3 }}
                  className={`${bgColor} rounded-2xl p-4 shadow-sm border ${borderColor} relative overflow-hidden`}
                >
                  <div className="flex items-start gap-3">
                    <div className={`w-12 h-12 rounded-xl bg-white flex items-center justify-center flex-shrink-0`}>
                      <Icon className={`w-6 h-6 ${iconColor}`} strokeWidth={2.5} />
                    </div>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-2">
                        <h3 className="font-semibold text-gray-900 capitalize">
                          {pedido.tipo}
                        </h3>
                        <div className="flex items-center gap-1 text-xs text-gray-500">
                          <Clock className="w-3 h-3" />
                          <span>{pedido.hora.slice(0, 5)}</span>
                        </div>
                      </div>

                      <div className="space-y-1 mb-3">
                        {pedido.items.map((item, idx) => (
                          <p key={idx} className="text-sm text-gray-700">
                            <span className="font-medium">{item.cantidad}x</span> {item.nombre}
                          </p>
                        ))}
                      </div>

                      <div className="flex items-center justify-between">
                        <p className="text-lg font-bold text-gray-900">
                          S/ {Number(pedido.total).toFixed(2)}
                        </p>
                        <motion.button
                          whileTap={{ scale: 0.9 }}
                          onClick={() => handleDelete(pedido.id)}
                          className="w-8 h-8 rounded-lg bg-red-100 flex items-center justify-center"
                        >
                          <Trash2 className="w-4 h-4 text-red-600" />
                        </motion.button>
                      </div>
                    </div>
                  </div>
                </motion.div>
              );
            })}
          </AnimatePresence>
        </div>
      )}
    </div>
  );
}
