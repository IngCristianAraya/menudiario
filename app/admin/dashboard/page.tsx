import { Card } from '@/components/ui/card';
import { BarChart, Clock, Users, Utensils } from 'lucide-react';

export default function DashboardPage() {
  // Datos de ejemplo - en un caso real, estos vendrían de tu base de datos
  const stats = [
    { name: 'Restaurantes Activos', value: '24', icon: Utensils, change: '+12%', changeType: 'increase' },
    { name: 'Pedidos Hoy', value: '156', icon: Clock, change: '+5%', changeType: 'increase' },
    { name: 'Usuarios Totales', value: '1,234', icon: Users, change: '+8%', changeType: 'increase' },
    { name: 'Ingresos del Mes', value: 'S/ 24,560', icon: BarChart, change: '+18%', changeType: 'increase' },
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold leading-7 text-gray-900 sm:truncate sm:text-3xl sm:tracking-tight">
          Panel de Control
        </h2>
        <p className="mt-1 text-sm text-gray-500">
          Resumen general de la plataforma
        </p>
      </div>

      {/* Estadísticas */}
      <div className="grid grid-cols-1 gap-5 mt-6 sm:grid-cols-2 lg:grid-cols-4">
        {stats.map((stat) => (
          <Card key={stat.name} className="px-5 py-4 overflow-hidden bg-white">
            <div className="flex items-center">
              <div className="flex-shrink-0 p-3 rounded-md bg-indigo-500 bg-opacity-10">
                <stat.icon className="w-6 h-6 text-indigo-600" aria-hidden="true" />
              </div>
              <div className="flex-1 ml-4">
                <p className="text-sm font-medium text-gray-500 truncate">{stat.name}</p>
                <div className="flex items-baseline">
                  <p className="text-2xl font-semibold text-gray-900">{stat.value}</p>
                  <p
                    className={`ml-2 text-sm font-medium ${
                      stat.changeType === 'increase' ? 'text-green-600' : 'text-red-600'
                    }`}
                  >
                    {stat.change}
                  </p>
                </div>
              </div>
            </div>
          </Card>
        ))}
      </div>

      {/* Gráficos y más contenido */}
      <div className="grid grid-cols-1 mt-6 gap-6 lg:grid-cols-2">
        <Card className="p-6">
          <h3 className="text-lg font-medium text-gray-900">Actividad Reciente</h3>
          <div className="mt-4">
            {/* Aquí iría un gráfico o lista de actividades */}
            <div className="space-y-4">
              {[1, 2, 3, 4, 5].map((i) => (
                <div key={i} className="flex items-start">
                  <div className="flex-shrink-0 w-2 h-2 mt-2 bg-indigo-500 rounded-full"></div>
                  <div className="ml-3">
                    <p className="text-sm font-medium text-gray-900">
                      Nuevo pedido #100{i}
                    </p>
                    <p className="text-sm text-gray-500">Hace {i * 2} horas</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </Card>

        <Card className="p-6">
          <h3 className="text-lg font-medium text-gray-900">Restaurantes Populares</h3>
          <div className="mt-4">
            {/* Lista de restaurantes */}
            <div className="overflow-hidden border border-gray-200 rounded-lg">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th scope="col" className="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">
                      Nombre
                    </th>
                    <th scope="col" className="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">
                      Pedidos
                    </th>
                    <th scope="col" className="px-6 py-3 text-xs font-medium tracking-wider text-left text-gray-500 uppercase">
                      Estado
                    </th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {[
                    { name: 'La Pizzería', orders: 45, status: 'Activo' },
                    { name: 'Sushi Express', orders: 32, status: 'Activo' },
                    { name: 'Café Aroma', orders: 28, status: 'Inactivo' },
                    { name: 'Burger House', orders: 21, status: 'Activo' },
                  ].map((restaurant, idx) => (
                    <tr key={idx}>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm font-medium text-gray-900">{restaurant.name}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <div className="text-sm text-gray-900">{restaurant.orders}</div>
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <span className={`inline-flex px-2 text-xs font-semibold leading-5 rounded-full ${
                          restaurant.status === 'Activo' 
                            ? 'bg-green-100 text-green-800' 
                            : 'bg-yellow-100 text-yellow-800'
                        }`}>
                          {restaurant.status}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
