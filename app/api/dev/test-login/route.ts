import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST(request: Request) {
  // Solo permitido en desarrollo
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ ok: false, error: 'No permitido en producción' }, { status: 403 });
  }

  const { email, password } = await request.json();

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!url || !anonKey) {
    return NextResponse.json(
      { ok: false, error: 'Faltan variables NEXT_PUBLIC_SUPABASE_URL o NEXT_PUBLIC_SUPABASE_ANON_KEY' },
      { status: 500 }
    );
  }

  // Usar cliente anónimo (como lo haría el login normal)
  const supabase = createClient(url, anonKey);

  try {
    // Intentar hacer login con las credenciales
    const { data, error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      return NextResponse.json({
        ok: false,
        error: error.message,
        details: {
          error_code: error.status,
          error_name: error.name
        }
      }, { status: 400 });
    }

    // Si el login es exitoso, cerrar la sesión inmediatamente (es solo una prueba)
    await supabase.auth.signOut();

    return NextResponse.json({
      ok: true,
      message: 'Credenciales válidas',
      user: {
        id: data.user?.id,
        email: data.user?.email,
        confirmed_at: data.user?.email_confirmed_at
      }
    });

  } catch (err: any) {
    return NextResponse.json({
      ok: false,
      error: 'Error inesperado',
      details: err.message
    }, { status: 500 });
  }
}

export async function GET() {
  return NextResponse.json({
    message: 'Endpoint para probar login. Usa POST con { "email": "admin@ejemplo.com", "password": "admin123" }'
  });
}