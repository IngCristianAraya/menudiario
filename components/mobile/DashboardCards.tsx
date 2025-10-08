'use client';

import { motion } from 'framer-motion';
import { ShoppingCart, DollarSign, Truck, TrendingUp } from 'lucide-react';
import type { ResumenDiario } from '@/lib/supabase';

interface DashboardCardsProps {
  resumen: ResumenDiario;
}

const cardVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: {
    opacity: 1,
    y: 0,
  },
};

export default function DashboardCards({ resumen }: DashboardCardsProps) {
  const cards = [
    {
      title: 'Pedidos Hoy',
      value: resumen.total_pedidos,
      icon: ShoppingCart,
      color: 'from-green-500 to-green-600',
      bg: 'bg-green-50',
      iconColor: 'text-green-600',
    },
    {
      title: 'Ventas Total',
      value: `S/ ${resumen.total_ventas.toFixed(2)}`,
      icon: DollarSign,
      color: 'from-orange-500 to-orange-600',
      bg: 'bg-orange-50',
      iconColor: 'text-orange-600',
    },
    {
      title: 'Para Delivery',
      value: resumen.pedidos_delivery,
      icon: Truck,
      color: 'from-blue-500 to-blue-600',
      bg: 'bg-blue-50',
      iconColor: 'text-blue-600',
    },
    {
      title: 'En Local',
      value: resumen.pedidos_local,
      icon: TrendingUp,
      color: 'from-emerald-500 to-emerald-600',
      bg: 'bg-emerald-50',
      iconColor: 'text-emerald-600',
    },
  ];

  return (
    <div className="grid grid-cols-2 gap-3">
      {cards.map((card, index) => {
        const Icon = card.icon;
        return (
          <motion.div
            key={card.title}
            variants={cardVariants}
            initial="hidden"
            animate="visible"
            transition={{
              delay: index * 0.1,
              duration: 0.4,
            }}
            whileHover={{ scale: 1.02 }}
            whileTap={{ scale: 0.98 }}
            className="relative overflow-hidden"
          >
            <div className={`${card.bg} rounded-2xl p-4 shadow-sm border border-gray-100 h-full`}>
              <div className="flex flex-col h-full justify-between">
                <div className={`w-10 h-10 rounded-xl bg-gradient-to-br ${card.color} flex items-center justify-center mb-3 shadow-sm`}>
                  <Icon className="w-5 h-5 text-white" strokeWidth={2.5} />
                </div>
                <div>
                  <p className="text-xs font-medium text-gray-600 mb-1">
                    {card.title}
                  </p>
                  <p className="text-2xl font-bold text-gray-900">
                    {card.value}
                  </p>
                </div>
              </div>
            </div>
          </motion.div>
        );
      })}
    </div>
  );
}
