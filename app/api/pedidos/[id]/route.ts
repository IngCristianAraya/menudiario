import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';

export async function PUT(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const supabase = createRouteHandlerClient({ cookies });
    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (!session) {
      return new NextResponse('No autorizado', { status: 401 });
    }

    const { estado } = await request.json();
    
    if (!estado) {
      return new NextResponse('El campo estado es requerido', { status: 400 });
    }

    // Verificar que el estado sea válido
    const estadosValidos = ['pendiente', 'en_preparacion', 'listo', 'entregado', 'cancelado'];
    if (!estadosValidos.includes(estado)) {
      return new NextResponse('Estado no válido', { status: 400 });
    }

    // Verificar que el pedido existe y pertenece al restaurante del usuario
    const { data: pedido, error: pedidoError } = await supabase
      .from('pedidos')
      .select('restaurante_id')
      .eq('id', params.id)
      .single();

    if (pedidoError) {
      console.error('Error al buscar el pedido:', pedidoError);
      return new NextResponse('Pedido no encontrado', { status: 404 });
    }

    // Verificar que el usuario pertenece al restaurante del pedido (solo para personal)
    const { data: perfil } = await supabase
      .from('perfiles_usuarios')
      .select('restaurante_id, rol')
      .eq('id', session.user.id)
      .single();

    if (perfil?.rol !== 'admin' && perfil?.restaurante_id !== pedido.restaurante_id) {
      return new NextResponse('No autorizado para actualizar este pedido', { status: 403 });
    }

    // Actualizar el estado del pedido
    const { data: pedidoActualizado, error: updateError } = await supabase
      .from('pedidos')
      .update({ estado })
      .eq('id', params.id)
      .select()
      .single();

    if (updateError) {
      console.error('Error al actualizar el pedido:', updateError);
      return new NextResponse('Error al actualizar el pedido', { status: 500 });
    }

    return NextResponse.json(pedidoActualizado);
  } catch (error) {
    console.error('Error al actualizar el pedido:', error);
    return new NextResponse('Error interno del servidor', { status: 500 });
  }
}

export async function GET(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const supabase = createRouteHandlerClient({ cookies });
    const {
      data: { session },
    } = await supabase.auth.getSession();

    if (!session) {
      return new NextResponse('No autorizado', { status: 401 });
    }

    // Obtener el pedido con sus ítems
    const { data: pedido, error } = await supabase
      .from('pedidos')
      .select(`
        *,
        items_pedido:items_pedido(*, platos(*)),
        cliente:cliente_id(id, email, perfiles_usuarios(*))
      `)
      .eq('id', params.id)
      .single();

    if (error) {
      console.error('Error al obtener el pedido:', error);
      return new NextResponse('Pedido no encontrado', { status: 404 });
    }

    // Verificar que el usuario tiene permiso para ver este pedido
    const { data: perfil } = await supabase
      .from('perfiles_usuarios')
      .select('restaurante_id, rol')
      .eq('id', session.user.id)
      .single();

    if (
      perfil?.rol !== 'admin' && 
      perfil?.restaurante_id !== pedido.restaurante_id &&
      pedido.cliente_id !== session.user.id
    ) {
      return new NextResponse('No autorizado para ver este pedido', { status: 403 });
    }

    return NextResponse.json(pedido);
  } catch (error) {
    console.error('Error al obtener el pedido:', error);
    return new NextResponse('Error interno del servidor', { status: 500 });
  }
}
