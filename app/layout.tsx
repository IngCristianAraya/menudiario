import './globals.css';
import type { Metadata } from 'next';
import { Inter } from 'next/font/google';
import { Providers } from './providers';
import BottomNav from '@/components/shared/BottomNav';

const inter = Inter({ subsets: ['latin'], weight: ['400', '500', '600', '700'] });

// Evitar prerender/SSG en build: fuerza renderizado dinámico del árbol
export const dynamic = 'force-dynamic';
export const revalidate = 0;

export const metadata: Metadata = {
  title: 'Pedidos Diarios',
  description: 'Sistema de gestión de pedidos para tu negocio',
  viewport: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no',
  themeColor: '#16A34A',
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="es" suppressHydrationWarning>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
      </head>
      <body className={inter.className}>
        <Providers>
          <div className="min-h-screen pb-20">
            {children}
          </div>
          <BottomNav />
        </Providers>
      </body>
    </html>
  );
}
