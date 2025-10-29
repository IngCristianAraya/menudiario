import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(request: Request) {
  // Solo permitido en desarrollo
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ ok: false, error: 'No permitido en producción' }, { status: 403 });
  }

  const { email, password, user_metadata } = await request.json().catch(() => ({}));
  if (!email || !password) {
    return NextResponse.json({ ok: false, error: 'email y password requeridos' }, { status: 400 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    return NextResponse.json(
      { ok: false, error: 'Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY' },
      { status: 500 }
    );
  }

  const supabase = createClient(url, serviceRoleKey, { auth: { autoRefreshToken: false, persistSession: false } });

  try {
    const { data, error } = await supabase.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: user_metadata || {},
    });

    if (error) {
      const msg = String(error.message || '').toLowerCase();
      // Si el usuario ya existe, actualizar la contraseña
      if (msg.includes('already') || msg.includes('registered') || msg.includes('exists')) {
        try {
          const { data: users, error: listError } = await supabase.auth.admin.listUsers();
          if (listError) {
            return NextResponse.json({ ok: false, error: `Error buscando usuarios: ${listError.message}` }, { status: 500 });
          }

          const existing = users?.users?.find((u: any) => u.email === email);
          if (!existing) {
            return NextResponse.json({ ok: false, error: 'Usuario existente no encontrado en listado' }, { status: 404 });
          }

          const { error: updError } = await supabase.auth.admin.updateUserById(existing.id, { password, user_metadata: user_metadata || {} });
          if (updError) {
            return NextResponse.json({ ok: false, error: `Error actualizando contraseña: ${updError.message}` }, { status: 500 });
          }

          return NextResponse.json({ ok: true, user: { id: existing.id, email }, note: 'Usuario existente - contraseña actualizada' });
        } catch (e: any) {
          return NextResponse.json({ ok: false, error: e?.message || 'Error actualizando usuario existente' }, { status: 500 });
        }
      }

      return NextResponse.json({ ok: false, error: error.message }, { status: 400 });
    }

    return NextResponse.json({ ok: true, user: { id: data.user?.id, email: data.user?.email } });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || 'Error creando usuario' }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({
    message: 'POST { email, password, user_metadata? } para crear usuario en Supabase Auth (solo dev)'
  });
}