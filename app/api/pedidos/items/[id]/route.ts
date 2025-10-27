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

    const { estado, notas } = await request.json();
    
    // Validar que al menos un campo se esté actualizando
    if (estado === undefined && !notas) {
      return new NextResponse('Se requiere al menos un campo para actualizar', { status: 400 });
    }

    // Verificar que el ítem existe y obtener el pedido al que pertenece
    const { data: item, error: itemError } = await supabase
      .from('items_pedido')
      .select('*, pedido:pedido_id(restaurante_id)')
      .eq('id', params.id)
      .single();

    if (itemError || !item) {
      console.error('Error al buscar el ítem:', itemError);
      return new NextResponse('Ítem no encontrado', { status: 404 });
    }

    // Verificar que el usuario pertenece al restaurante del pedido
    const { data: perfil } = await supabase
      .from('perfiles_usuarios')
      .select('restaurante_id, rol')
      .eq('id', session.user.id)
      .single();

    if (
      perfil?.rol !== 'admin' && 
      perfil?.restaurante_id !== (item.pedido as any).restaurante_id
    ) {
      return new NextResponse('No autorizado para actualizar este ítem', { status: 403 });
    }

    // Preparar datos para actualizar
    const updateData: any = {};
    if (estado !== undefined) updateData.estado = estado;
    if (notas !== undefined) updateData.notas = notas;

    // Actualizar el ítem
    const { data: itemActualizado, error: updateError } = await supabase
      .from('items_pedido')
      .update(updateData)
      .eq('id', params.id)
      .select('*')
      .single();

    if (updateError) {
      console.error('Error al actualizar el ítem:', updateError);
      return new NextResponse('Error al actualizar el ítem', { status: 500 });
    }

    return NextResponse.json(itemActualizado);
  } catch (error) {
    console.error('Error al actualizar el ítem:', error);
    return new NextResponse('Error interno del servidor', { status: 500 });
  }
}

export async function DELETE(
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

    // Verificar que el ítem existe y obtener el pedido al que pertenece
    const { data: item, error: itemError } = await supabase
      .from('items_pedido')
      .select('*, pedido:pedido_id(restaurante_id, estado)')
      .eq('id', params.id)
      .single();

    if (itemError || !item) {
      console.error('Error al buscar el ítem:', itemError);
      return new NextResponse('Ítem no encontrado', { status: 404 });
    }

    // No permitir eliminar ítems de pedidos ya entregados o cancelados
    if (['entregado', 'cancelado'].includes((item.pedido as any).estado)) {
      return new NextResponse('No se puede modificar un pedido ya entregado o cancelado', { status: 400 });
    }

    // Verificar que el usuario pertenece al restaurante del pedido o es el cliente
    const { data: perfil } = await supabase
      .from('perfiles_usuarios')
      .select('restaurante_id, rol')
      .eq('id', session.user.id)
      .single();

    const esPersonalRestaurante = perfil?.rol === 'admin' || 
      perfil?.restaurante_id === (item.pedido as any).restaurante_id;
    
    const esCliente = item.cliente_id === session.user.id;

    if (!esPersonalRestaurante && !esCliente) {
      return new NextResponse('No autorizado para eliminar este ítem', { status: 403 });
    }

    // Eliminar el ítem
    const { error: deleteError } = await supabase
      .from('items_pedido')
      .delete()
      .eq('id', params.id);

    if (deleteError) {
      console.error('Error al eliminar el ítem:', deleteError);
      return new NextResponse('Error al eliminar el ítem', { status: 500 });
    }

    return new NextResponse(null, { status: 204 });
  } catch (error) {
    console.error('Error al eliminar el ítem:', error);
    return new NextResponse('Error interno del servidor', { status: 500 });
  }
}
