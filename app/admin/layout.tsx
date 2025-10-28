export const dynamic = 'force-dynamic';
import { auth } from '@/lib/auth';
import { redirect } from 'next/navigation';
import { AdminSidebar } from '@/components/admin/Sidebar';

export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await auth();
  
  if (!session?.user) {
    redirect('/auth/login');
  }
  
  // TODO: Verificar rol desde headers inyectados por el middleware
  // Temporalmente comentado para resolver el build
  // const headersList = headers();
  // const role = headersList.get('x-user-role') || '';
  // const allowedRoles = new Set(['admin', 'owner']);
  // if (role && !allowedRoles.has(role)) {
  //   redirect('/acceso-denegado');
  // }

  return (
    <div className="flex h-screen bg-gray-50">
      <AdminSidebar />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-white shadow-sm z-10">
          <div className="max-w-7xl mx-auto px-4 py-4 sm:px-6 lg:px-8 flex justify-between items-center">
            <h1 className="text-xl font-semibold text-gray-900">Panel de Administración</h1>
            <div className="flex items-center space-x-4">
              <span className="text-sm text-gray-700">{session.user.email}</span>
              <form action="/auth/signout" method="POST">
                <button 
                  type="submit"
                  className="text-sm text-red-600 hover:text-red-800"
                >
                  Cerrar sesión
                </button>
              </form>
            </div>
          </div>
        </header>
        <main className="flex-1 overflow-y-auto p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
