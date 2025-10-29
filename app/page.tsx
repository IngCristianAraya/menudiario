'use client';

import { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import type { ResumenDiario } from '@/lib/supabase';
import DashboardCards from '@/components/mobile/DashboardCards';
import { Calendar, TrendingUp } from 'lucide-react';

export default function Home() {
  const [resumen, setResumen] = useState<ResumenDiario>({
    total_pedidos: 0,
    total_ventas: 0,
    pedidos_local: 0,
    pedidos_delivery: 0,
  });
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadResumen();
  }, []);

  // Función para cargar datos de prueba (mockup)
  const loadMockupData = () => {
    // Obtener datos guardados en localStorage o usar valores por defecto
    const mockPedidos = JSON.parse(localStorage.getItem('mockPedidos') || '[]');
    const hoy = new Date().toISOString().split('T')[0];
    
    // Filtrar pedidos de hoy
    const pedidosHoy = mockPedidos.filter((p: any) => p.fecha === hoy);
    
    // Calcular resumen
    const totalPedidos = pedidosHoy.length;
    const totalVentas = pedidosHoy.reduce((sum: number, p: any) => sum + Number(p.total), 0);
    const pedidosLocal = pedidosHoy.filter((p: any) => p.tipo === 'local').length;
    const pedidosDelivery = pedidosHoy.filter((p: any) => p.tipo === 'delivery').length;

    setResumen({
      total_pedidos: totalPedidos,
      total_ventas: totalVentas,
      pedidos_local: pedidosLocal,
      pedidos_delivery: pedidosDelivery,
    });
    setLoading(false);
  };

  const loadResumen = async () => {
    try {
      // Cargar datos de prueba directamente
      loadMockupData();
      // No es necesario el resto del código ya que estamos en modo mockup
      return;
      
      /* Código para conexión real a Supabase (comentado por ahora)
      const hoy = new Date().toISOString().split('T')[0];
      
      // Usar tipo any temporalmente para evitar problemas de tipos
      const { data, error } = await supabase
        .from('pedidos_diarios')
        .select('tipo, total')
        .eq('fecha', hoy);

      if (error) {
        console.error('Error fetching pedidos:', error);
        throw error;
      }

      // Procesar datos de manera segura
      if (data) {
        const pedidos = Array.isArray(data) ? data : [data];
        const totalPedidos = pedidos.length;
        const totalVentas = pedidos.reduce((sum, p) => {
          const total = p?.total ? Number(p.total) : 0;
          return isNaN(total) ? sum : sum + total;
        }, 0);
        
        const pedidosLocal = pedidos.filter(p => p?.tipo === 'local').length;
        const pedidosDelivery = pedidos.filter(p => p?.tipo === 'delivery').length;

        setResumen({
          total_pedidos: totalPedidos,
          total_ventas: totalVentas,
          pedidos_local: pedidosLocal,
          pedidos_delivery: pedidosDelivery,
        });
      }
      */
    } catch (error) {
      console.error('Error loading resumen:', error);
      // Si hay error, cargar datos de prueba
      loadMockupData();
    } finally {
      setLoading(false);
    }
  };

  const today = new Date().toLocaleDateString('es-ES', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  return (
    <div className="max-w-[430px] mx-auto px-4 py-6 safe-top">
      <motion.div
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="mb-6"
      >
        <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-3xl p-6 shadow-lg mb-4">
          <div className="flex items-center gap-2 mb-2">
            <Calendar className="w-5 h-5 text-white/90" />
            <p className="text-white/90 text-sm font-medium capitalize">
              {today}
            </p>
          </div>
          <h1 className="text-3xl font-bold text-white mb-1">
            Pedidos Diarios
          </h1>
          <p className="text-white/80 text-sm">
            Panel de control de tu negocio
          </p>
        </div>
      </motion.div>

      {loading ? (
        <div className="grid grid-cols-2 gap-3">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="bg-gray-100 rounded-2xl p-4 h-32 animate-pulse" />
          ))}
        </div>
      ) : (
        <DashboardCards resumen={resumen} />
      )}

      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5, duration: 0.5 }}
        className="mt-6 bg-white rounded-2xl p-4 shadow-sm border border-gray-100"
      >
        <div className="flex items-center gap-2 mb-2">
          <TrendingUp className="w-5 h-5 text-green-600" />
          <h2 className="text-lg font-semibold text-gray-900">
            Resumen del Día
          </h2>
        </div>
        <p className="text-sm text-gray-600">
          {resumen.total_pedidos === 0
            ? 'Aún no hay pedidos registrados hoy. ¡Comienza a registrar!'
            : `Llevas ${resumen.total_pedidos} pedido${resumen.total_pedidos !== 1 ? 's' : ''} registrado${resumen.total_pedidos !== 1 ? 's' : ''} con un total de S/ ${resumen.total_ventas.toFixed(2)} en ventas.`}
        </p>
      </motion.div>
    </div>
  );
}
