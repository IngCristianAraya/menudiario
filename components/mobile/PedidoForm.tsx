'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { motion, AnimatePresence } from 'framer-motion';
import { Plus, Minus, Check, Store, Truck, Utensils, Soup, GlassWater, Package } from 'lucide-react';

type Categoria = 'entrada' | 'segundo' | 'bebida';

interface PlatoSeleccionado {
  id: string;
  nombre: string;
  precio: number;
  categoria: Categoria;
}

type Plato = {
  id: string;
  nombre: string;
  precio: number;
  categoria: Categoria;
  activo: boolean;
  created_at: string;
};

const menuEjemplo: Plato[] = [
  { id: 'e1', nombre: 'Sopa del día', precio: 5, categoria: 'entrada', activo: true, created_at: new Date().toISOString() },
  { id: 'e2', nombre: 'Tequeños', precio: 5, categoria: 'entrada', activo: true, created_at: new Date().toISOString() },
  { id: 'e3', nombre: 'Papa a la Huancaína', precio: 5, categoria: 'entrada', activo: true, created_at: new Date().toISOString() },
  { id: 'e4', nombre: 'Ensalada Mixta', precio: 5, categoria: 'entrada', activo: true, created_at: new Date().toISOString() },
  { id: 's1', nombre: 'Arroz con Pollo', precio: 12, categoria: 'segundo', activo: true, created_at: new Date().toISOString() },
  { id: 's2', nombre: 'Tallarín Verde', precio: 12, categoria: 'segundo', activo: true, created_at: new Date().toISOString() },
  { id: 's3', nombre: 'Ají de Gallina', precio: 12, categoria: 'segundo', activo: true, created_at: new Date().toISOString() },
  { id: 's4', nombre: 'Pollo a la Parrilla', precio: 12, categoria: 'segundo', activo: true, created_at: new Date().toISOString() },
  { id: 'b1', nombre: 'Limonada (Refresco del día)', precio: 0, categoria: 'bebida', activo: true, created_at: new Date().toISOString() },
  { id: 'b2', nombre: 'Chicha Morada', precio: 5, categoria: 'bebida', activo: true, created_at: new Date().toISOString() },
  { id: 'b3', nombre: 'Maracuyá', precio: 6, categoria: 'bebida', activo: true, created_at: new Date().toISOString() },
  { id: 'b4', nombre: 'Agua Mineral', precio: 3, categoria: 'bebida', activo: true, created_at: new Date().toISOString() },
];

const agruparPorCategoria = (platos: Plato[]): Record<Categoria, Plato[]> => {
  return platos.reduce((acc, plato) => {
    if (!acc[plato.categoria]) {
      acc[plato.categoria] = [];
    }
    acc[plato.categoria].push(plato);
    return acc;
  }, {} as Record<Categoria, Plato[]>);
};

export default function PedidoForm() {
  const router = useRouter();
  type TipoPedido = 'local' | 'llevar' | 'delivery';
  const [tipo, setTipo] = useState<TipoPedido>('local');
  const [usarTaper, setUsarTaper] = useState(true);
  const [seleccion, setSeleccion] = useState<{
    entrada: Plato | null;
    segundo: Plato | null;
    bebida: Plato | null;
  }>({ entrada: null, segundo: null, bebida: null });
  const [cantidad, setCantidad] = useState(1);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  const [menu, setMenu] = useState<Plato[]>([]);
  const [menuPorCategoria, setMenuPorCategoria] = useState<Record<Categoria, Plato[]>>({
    entrada: [],
    segundo: [],
    bebida: []
  });

  useEffect(() => {
    setMenu(menuEjemplo);
    setMenuPorCategoria(agruparPorCategoria(menuEjemplo));
  }, []);

  const seleccionarPlato = (plato: Plato) => {
    setSeleccion(prev => ({
      ...prev,
      [plato.categoria]: prev[plato.categoria as keyof typeof prev]?.id === plato.id ? null : plato
    }));
  };

  const obtenerPlatoSeleccionado = (categoria: Categoria): Plato | null => {
    switch (categoria) {
      case 'entrada': return seleccion.entrada;
      case 'segundo': return seleccion.segundo;
      case 'bebida': return seleccion.bebida;
      default: return null;
    }
  };

  const calcularTotal = (): number => {
    let total = 0;
    
    if (seleccion.segundo) {
      total = 12;
      
      if (seleccion.bebida && seleccion.bebida.id !== 'b1') {
        total += seleccion.bebida.precio * cantidad;
      }
      
      if (tipo === 'llevar' && usarTaper) {
        total += 1;
      } else if (tipo === 'delivery') {
        total += 2;
      }
    } else if (seleccion.entrada && !seleccion.segundo) {
      total = 5 * cantidad;
    } else if (seleccion.bebida && !seleccion.entrada && !seleccion.segundo) {
      total = seleccion.bebida.id === 'b1' ? 0 : seleccion.bebida.precio * cantidad;
    }
    
    return total * cantidad;
  };

  const handleSubmit = async () => {
    if (!seleccion.segundo) {
      alert('Debe seleccionar al menos un segundo');
      return;
    }

    setSaving(true);
    try {
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const nuevoPedido = {
        id: Date.now().toString(),
        tipo,
        items: Object.entries(seleccion)
          .filter(([_, plato]) => plato !== null)
          .map(([categoria, plato]) => ({
            plato_id: plato!.id,
            nombre: plato!.nombre,
            precio: plato!.precio,
            categoria: categoria as Categoria
          })),
        total: calcularTotal(),
        fecha: new Date().toISOString().split('T')[0],
        hora: new Date().toLocaleTimeString(),
        cantidad,
        created_at: new Date().toISOString(),
        estado: 'pendiente' as const
      };

      const pedidosAnteriores = JSON.parse(localStorage.getItem('mockPedidos') || '[]');
      localStorage.setItem('mockPedidos', JSON.stringify([...pedidosAnteriores, nuevoPedido]));

      setShowSuccess(true);
      setTimeout(() => {
        setShowSuccess(false);
        router.push('/');
      }, 2000);
    } catch (error) {
      console.error('Error al guardar el pedido:', error);
      alert('Error al guardar el pedido');
    } finally {
      setSaving(false);
    }
  };

  const haySeleccion = seleccion.entrada !== null || seleccion.segundo !== null || seleccion.bebida !== null;
  const total = calcularTotal();

  const renderCategoria = (categoria: Categoria, titulo: string, icono: React.ReactNode) => {
    const platos = menuPorCategoria[categoria] || [];
    const platoSeleccionado = obtenerPlatoSeleccionado(categoria);
    
    return (
      <div className="mb-6">
        <div className="flex items-center gap-2 mb-3">
          {icono}
          <h2 className="text-lg font-semibold text-gray-800">{titulo}</h2>
          {platoSeleccionado && (
            <span className="ml-2 px-3 py-1.5 bg-green-100 text-green-800 text-sm font-medium rounded-full border border-green-200 flex items-center">
              <Check className="h-3.5 w-3.5 mr-1.5" />
              Seleccionado: {platoSeleccionado.nombre}
            </span>
          )}
        </div>
        <div className="grid grid-cols-2 gap-2">
          {platos.map((plato) => (
            <motion.button
              key={plato.id}
              whileTap={{ scale: 0.98 }}
              onClick={() => seleccionarPlato(plato)}
              className={`p-3 rounded-xl text-left transition-all ${
                seleccion[plato.categoria as keyof typeof seleccion]?.id === plato.id
                  ? 'bg-blue-50 border-2 border-blue-400'
                  : 'bg-white border border-gray-200'
              }`}
            >
              <p className="font-medium text-gray-900">{plato.nombre}</p>
              <p className="text-sm text-gray-500">S/ {plato.precio.toFixed(2)}</p>
            </motion.button>
          ))}
        </div>
      </div>
    );
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  return (
    <>
      <div className="min-h-screen bg-gray-50 pb-32">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="max-w-md mx-auto bg-white min-h-screen shadow-lg"
        >
          <div className="p-6">
            <h1 className="text-2xl font-bold text-gray-900 mb-2">Nuevo Pedido</h1>
            <p className="text-gray-600 mb-4">Selecciona tu menú del día</p>

            <div className="grid grid-cols-3 gap-2 mb-6">
              <motion.button
                whileTap={{ scale: 0.98 }}
                onClick={() => setTipo('local')}
                className={`flex flex-col items-center justify-center gap-1 py-3 px-2 rounded-xl font-medium transition-all ${
                  tipo === 'local'
                    ? 'bg-green-100 text-green-700 border-2 border-green-400'
                    : 'bg-white text-gray-700 border border-gray-200'
                }`}
              >
                <Store className="w-5 h-5" />
                <span className="text-sm">En Local</span>
                <span className="text-xs text-gray-500">S/ 12.00</span>
              </motion.button>

              <motion.button
                whileTap={{ scale: 0.98 }}
                onClick={() => setTipo('llevar')}
                className={`flex flex-col items-center justify-center gap-1 py-3 px-2 rounded-xl font-medium transition-all ${
                  tipo === 'llevar'
                    ? 'bg-yellow-100 text-yellow-700 border-2 border-yellow-400'
                    : 'bg-white text-gray-700 border border-gray-200'
                }`}
              >
                <Package className="w-5 h-5" />
                <span className="text-sm">Para Llevar</span>
                <span className="text-xs text-gray-500">
                  {usarTaper ? 'S/ 13.00' : 'S/ 12.00'}
                </span>
              </motion.button>

              <motion.button
                whileTap={{ scale: 0.98 }}
                onClick={() => setTipo('delivery')}
                className={`flex flex-col items-center justify-center gap-1 py-3 px-2 rounded-xl font-medium transition-all ${
                  tipo === 'delivery'
                    ? 'bg-blue-100 text-blue-700 border-2 border-blue-400'
                    : 'bg-white text-gray-700 border border-gray-200'
                }`}
              >
                <Truck className="w-5 h-5" />
                <span className="text-sm">Delivery</span>
                <span className="text-xs text-gray-500">S/ 14.00</span>
              </motion.button>
            </div>

            {tipo === 'llevar' && (
              <motion.div 
                initial={{ opacity: 0, height: 0 }}
                animate={{ opacity: 1, height: 'auto' }}
                className="mb-4 flex items-center justify-between p-3 bg-gray-50 rounded-lg"
              >
                <div className="flex items-center">
                  <Package className="w-5 h-5 mr-2 text-yellow-600" />
                  <span className="text-sm font-medium text-gray-700">Incluir taper</span>
                </div>
                <button
                  type="button"
                  onClick={() => setUsarTaper(!usarTaper)}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none ${
                    usarTaper ? 'bg-yellow-500' : 'bg-gray-200'
                  }`}
                >
                  <span
                    className={`inline-block h-5 w-5 transform rounded-full bg-white shadow-md transition-transform ${
                      usarTaper ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
                <span className="text-sm text-gray-500 ml-2">+S/ 1.00</span>
              </motion.div>
            )}

            <div className="bg-white rounded-xl p-4 mb-6 border border-gray-200">
              <div className="flex justify-between items-center">
                <span className="font-medium">Cantidad de menús</span>
                <div className="flex items-center gap-3">
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => setCantidad(prev => Math.max(1, prev - 1))}
                    className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center"
                  >
                    <Minus className="w-4 h-4 text-gray-700" />
                  </motion.button>
                  <span className="w-8 text-center font-bold text-lg">{cantidad}</span>
                  <motion.button
                    whileTap={{ scale: 0.9 }}
                    onClick={() => setCantidad(prev => prev + 1)}
                    className="w-10 h-10 rounded-full bg-green-100 flex items-center justify-center"
                  >
                    <Plus className="w-4 h-4 text-green-700" />
                  </motion.button>
                </div>
              </div>
            </div>

            {renderCategoria('entrada', 'Entradas (Opcional)', <Soup className="w-5 h-5 text-orange-500" />)}
            {renderCategoria('segundo', 'Segundos (Obligatorio)', <Utensils className="w-5 h-5 text-blue-500" />)}
            {renderCategoria('bebida', 'Bebidas (Opcional)', <GlassWater className="w-5 h-5 text-green-500" />)}
          </div>
        </motion.div>
      </div>

      <AnimatePresence>
        {haySeleccion && (
          <motion.div
            initial={{ y: 100, opacity: 0 }}
            animate={{ y: 0, opacity: 1 }}
            exit={{ y: 100, opacity: 0 }}
            className="fixed bottom-20 left-0 right-0 px-4 pb-4 safe-bottom z-40"
          >
            <div className="max-w-[430px] mx-auto">
              <div className="bg-white rounded-2xl p-4 shadow-xl border border-gray-200">
                <div className="flex items-center justify-between mb-3">
                  <div>
                    <p className="text-sm text-gray-600">
                      {cantidad} menú{cantidad !== 1 ? 's' : ''} • {Object.values(seleccion).filter(Boolean).length} ítem{Object.values(seleccion).filter(Boolean).length !== 1 ? 's' : ''}
                    </p>
                    <p className="text-2xl font-bold text-gray-900">S/ {total.toFixed(2)}</p>
                  </div>
                  <motion.button
                    whileTap={{ scale: 0.95 }}
                    onClick={handleSubmit}
                    disabled={saving || !seleccion.segundo}
                    className={`px-6 py-3 rounded-xl font-semibold shadow-lg flex items-center gap-2 ${
                      saving || !seleccion.segundo
                        ? 'bg-gray-300 text-gray-500 cursor-not-allowed'
                        : 'bg-gradient-to-br from-green-500 to-green-600 text-white'
                    }`}
                  >
                    {saving ? (
                      <span>Guardando...</span>
                    ) : (
                      <>
                        <Check className="w-5 h-5" />
                        <span>Confirmar</span>
                      </>
                    )}
                  </motion.button>
                </div>

                <div className="mt-3 pt-3 border-t border-gray-100">
                  <p className="text-sm text-gray-600 mb-2">Tu selección:</p>
                  <div className="flex flex-wrap gap-2">
                    {Object.entries(seleccion)
                      .filter(([_, plato]) => plato !== null)
                      .map(([categoria, plato]) => {
                        if (!plato) return null;
                        return (
                          <span
                            key={`${categoria}-${plato.id}`}
                            className="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded-full flex items-center gap-1"
                          >
                            {categoria === 'entrada' && <Soup className="w-3 h-3" />}
                            {categoria === 'segundo' && <Utensils className="w-3 h-3" />}
                            {categoria === 'bebida' && <GlassWater className="w-3 h-3" />}
                            {plato.nombre}
                          </span>
                        );
                      })}
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      <AnimatePresence>
        {showSuccess && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
          >
            <motion.div
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              exit={{ scale: 0.8, opacity: 0 }}
              className="bg-white rounded-3xl p-8 m-4 text-center shadow-2xl"
            >
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <Check className="w-8 h-8 text-green-600" />
              </div>
              <h2 className="text-xl font-bold text-gray-900 mb-2">
                ¡Pedido Guardado!
              </h2>
              <p className="text-gray-600">
                El pedido se registró correctamente
              </p>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}