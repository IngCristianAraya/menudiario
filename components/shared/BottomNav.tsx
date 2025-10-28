'use client';

import * as React from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { getSession } from 'next-auth/react';
import { Home, Plus, ClipboardList, Settings } from 'lucide-react';
import { motion } from 'framer-motion';

function getNavItems(showAdmin: boolean) {
  const items = [
    { href: '/', icon: Home, label: 'Inicio' },
    { href: '/nuevo-pedido', icon: Plus, label: 'Nuevo', primary: true },
    { href: '/pedidos-hoy', icon: ClipboardList, label: 'Pedidos' },
  ];
  if (showAdmin) {
    items.push({ href: '/admin/dashboard', icon: Settings, label: 'Admin' });
  }
  return items;
}

export default function BottomNav() {
  const pathname = usePathname();
  const initialShowAdmin = process.env.NEXT_PUBLIC_SHOW_ADMIN_CTA === 'true';
  const [showAdmin, setShowAdmin] = React.useState<boolean>(initialShowAdmin);
  const [hasAdminRole, setHasAdminRole] = React.useState<boolean>(false);
  const [loadedFromConfig, setLoadedFromConfig] = React.useState<boolean>(false);

  React.useEffect(() => {
    try {
      const val = localStorage.getItem('showAdminCTA');
      if (val === 'true' || val === 'false') {
        setShowAdmin(val === 'true');
      }
    } catch {}
  }, []);

  React.useEffect(() => {
    // Obtener sesión de NextAuth sin necesitar SessionProvider
    getSession().then((session) => {
      const role = (session?.user as any)?.role as string | undefined;
      setHasAdminRole(role === 'admin' || role === 'owner');
    }).catch(() => {
      setHasAdminRole(false);
    });
  }, []);

  React.useEffect(() => {
    // Intentar cargar configuración del tenant para decidir visibilidad del CTA Admin
    // Respeta localStorage si el usuario lo fijó manualmente
    (async () => {
      try {
        const res = await fetch('/api/tenant/config', { cache: 'no-store' });
        if (!res.ok) return;
        const json = await res.json();
        const cfg = json?.config as { show_admin_cta?: boolean } | undefined;
        const localVal = typeof window !== 'undefined' ? localStorage.getItem('showAdminCTA') : null;
        const localDefined = localVal === 'true' || localVal === 'false';
        if (!localDefined && typeof cfg?.show_admin_cta === 'boolean') {
          setShowAdmin(cfg.show_admin_cta);
        }
        setLoadedFromConfig(true);
      } catch {
        // ignorar errores y mantener defaults/env/localStorage
        setLoadedFromConfig(true);
      }
    })();
  }, []);
  const showAdminCTA = hasAdminRole || showAdmin;

  return (
    <nav className="fixed bottom-0 left-0 right-0 bg-white/80 backdrop-blur-lg border-t border-gray-200 safe-bottom z-50">
      <div className="max-w-[430px] mx-auto px-4">
        <div className="flex items-center justify-around py-2">
          {getNavItems(showAdminCTA).map((item) => {
            const isActive = pathname === item.href;
            const Icon = item.icon;

            return (
              <Link
                key={item.href}
                href={item.href}
                className="relative flex flex-col items-center justify-center w-16 py-2 group"
              >
                {item.primary ? (
                  <motion.div
                    whileTap={{ scale: 0.9 }}
                    className="flex flex-col items-center"
                  >
                    <div className="bg-gradient-to-br from-green-500 to-green-600 rounded-2xl p-3 shadow-lg mb-1">
                      <Icon className="w-6 h-6 text-white" strokeWidth={2.5} />
                    </div>
                    <span className="text-[10px] font-medium text-gray-600">
                      {item.label}
                    </span>
                  </motion.div>
                ) : (
                  <motion.div
                    whileTap={{ scale: 0.9 }}
                    className="flex flex-col items-center"
                  >
                    <Icon
                      className={`w-6 h-6 mb-1 transition-colors ${
                        isActive ? 'text-green-600' : 'text-gray-400'
                      }`}
                      strokeWidth={isActive ? 2.5 : 2}
                    />
                    <span
                      className={`text-[10px] font-medium transition-colors ${
                        isActive ? 'text-green-600' : 'text-gray-500'
                      }`}
                    >
                      {item.label}
                    </span>
                    {isActive && (
                      <motion.div
                        layoutId="activeTab"
                        className="absolute -bottom-1 w-1 h-1 bg-green-600 rounded-full"
                        transition={{ type: 'spring', stiffness: 380, damping: 30 }}
                      />
                    )}
                  </motion.div>
                )}
              </Link>
            );
          })}
        </div>
      </div>
    </nav>
  );
}
