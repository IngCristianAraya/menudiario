import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

export async function POST(request: Request) {
  try {
    const supabase = createRouteHandlerClient({ cookies });
    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (!session) {
      return new NextResponse('No autorizado', { status: 401 });
    }

    const pedidoData = await request.json();
    
    // Validar datos del pedido
    if (!pedidoData.items || !Array.isArray(pedidoData.items) || pedidoData.items.length === 0) {
      return new NextResponse('El pedido debe contener al menos un ítem', { status: 400 });
    }

    // Obtener el perfil del usuario
    const { data: perfil } = await supabase
      .from('perfiles_usuarios')
      .select('restaurante_id')
      .eq('id', session.user.id)
      .single();

    if (!perfil?.restaurante_id) {
      return new NextResponse('No se pudo determinar el restaurante', { status: 400 });
    }

    // Generar código de pedido único (ejemplo: P-12345)
    const codigoPedido = `P-${Math.floor(10000 + Math.random() * 90000)}`;
    
    // Calcular total
    const total = pedidoData.items.reduce(
      (sum: number, item: any) => sum + (item.precio_unitario * item.cantidad),
      0
    );

    // Crear transacción
    const { data: pedido, error } = await supabase
      .from('pedidos')
      .insert([
        {
          codigo_pedido: codigoPedido,
          cliente_id: session.user.id,
          tipo_entrega: pedidoData.tipo_entrega,
          detalles_entrega: pedidoData.detalles_entrega || {},
          total,
          restaurante_id: perfil.restaurante_id,
        },
      ])
      .select()
      .single();

    if (error) {
      console.error('Error al crear el pedido:', error);
      return new NextResponse('Error al crear el pedido', { status: 500 });
    }

    // Crear ítems del pedido
    const itemsConPedidoId = pedidoData.items.map((item: any) => ({
      pedido_id: pedido.id,
      plato_id: item.plato_id,
      cantidad: item.cantidad,
      precio_unitario: item.precio_unitario,
      notas: item.notas || null,
    }));

    const { error: errorItems } = await supabase
      .from('items_pedido')
      .insert(itemsConPedidoId);

    if (errorItems) {
      // Si hay error al crear los ítems, eliminar el pedido creado
      await supabase.from('pedidos').delete().eq('id', pedido.id);
      console.error('Error al crear los ítems del pedido:', errorItems);
      return new NextResponse('Error al crear los ítems del pedido', { status: 500 });
    }

    return NextResponse.json({ ...pedido, codigo_pedido: codigoPedido });
  } catch (error) {
    console.error('Error en la creación del pedido:', error);
    return new NextResponse('Error interno del servidor', { status: 500 });
  }
}

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const supabase = createRouteHandlerClient({ cookies });
    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (!session) {
      return new NextResponse('No autorizado', { status: 401 });
    }

    // Obtener el perfil del usuario para verificar el restaurante
    const { data: perfil } = await supabase
      .from('perfiles_usuarios')
      .select('restaurante_id, rol')
      .eq('id', session.user.id)
      .single();

    if (!perfil) {
      return new NextResponse('Perfil de usuario no encontrado', { status: 404 });
    }

    // Construir la consulta base
    let query = supabase
      .from('pedidos')
      .select(`
        *,
        items_pedido:items_pedido(*, platos(*)),
        cliente:cliente_id(id, email, perfiles_usuarios(*))
      `);

    // Filtrar por restaurante
    if (perfil.rol !== 'admin') {
      query = query.eq('restaurante_id', perfil.restaurante_id);
    }

    // Filtrar por estado si se proporciona
    const estado = searchParams.get('estado');
    if (estado) {
      query = query.eq('estado', estado);
    }

    // Filtrar por fecha si se proporciona
    const fecha = searchParams.get('fecha');
    if (fecha) {
      const fechaInicio = new Date(fecha);
      fechaInicio.setHours(0, 0, 0, 0);
      
      const fechaFin = new Date(fecha);
      fechaFin.setHours(23, 59, 59, 999);
      
      query = query
        .gte('fecha_pedido', fechaInicio.toISOString())
        .lte('fecha_pedido', fechaFin.toISOString());
    }

    // Si es un cliente, solo mostrar sus propios pedidos
    if (perfil.rol === 'cliente') {
      query = query.eq('cliente_id', session.user.id);
    }

    // Ordenar por fecha de pedido (más reciente primero)
    query = query.order('fecha_pedido', { ascending: false });

    const { data: pedidos, error } = await query;

    if (error) {
      console.error('Error al obtener los pedidos:', error);
      return new NextResponse('Error al obtener los pedidos', { status: 500 });
    }

    return NextResponse.json(pedidos);
  } catch (error) {
    console.error('Error al obtener los pedidos:', error);
    return new NextResponse('Error interno del servidor', { status: 500 });
  }
}
