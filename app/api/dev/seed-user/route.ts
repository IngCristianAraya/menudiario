import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function GET() {
  // Solo permitido en desarrollo
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ ok: false, error: 'No permitido en producción' }, { status: 403 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    return NextResponse.json(
      { ok: false, error: 'Faltan variables NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY' },
      { status: 500 }
    );
  }

  const supabase = createClient(url, serviceRoleKey);

  const email = 'admin@ejemplo.com';
  const password = 'admin123';

  try {
    // Primero intentar crear el usuario
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nombre: 'Admin Ejemplo' },
    });

    if (error) {
      const msg = String(error.message || '').toLowerCase();
      // Si el usuario ya existe, intentar actualizar su contraseña
      if (msg.includes('already') || msg.includes('exists')) {
        try {
          // Buscar el usuario por email
          const { data: users, error: listError } = await supabase.auth.admin.listUsers();
          if (listError) {
            return NextResponse.json({ 
              ok: false, 
              error: `Error buscando usuarios: ${listError.message}` 
            }, { status: 500 });
          }

          const existingUser = users.users.find(u => u.email === email);
          if (existingUser) {
            // Actualizar la contraseña del usuario existente
            const { error: updateError } = await supabase.auth.admin.updateUserById(
              existingUser.id,
              { password }
            );

            if (updateError) {
              return NextResponse.json({ 
                ok: false, 
                error: `Error actualizando contraseña: ${updateError.message}` 
              }, { status: 500 });
            }

            return NextResponse.json({ 
              ok: true, 
              email, 
              password, 
              user_id: existingUser.id,
              note: 'Usuario existente - contraseña actualizada' 
            });
          }
        } catch (updateErr: any) {
          return NextResponse.json({ 
            ok: false, 
            error: `Error en actualización: ${updateErr.message}` 
          }, { status: 500 });
        }
      }
      return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
    }
  } catch (err: any) {
    return NextResponse.json({ 
      ok: false, 
      error: `Error general: ${err.message}` 
    }, { status: 500 });
  }

  return NextResponse.json({ ok: true, email, password, user_id: data?.user?.id || null });
}