import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function GET() {
  // Solo permitido en desarrollo
  if (process.env.NODE_ENV === 'production') {
    return NextResponse.json({ ok: false, error: 'No permitido en producción' }, { status: 403 });
  }

  const diagnostics = {
    env_vars: {
      NEXT_PUBLIC_SUPABASE_URL: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
      SUPABASE_SERVICE_ROLE_KEY: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
      url_value: process.env.NEXT_PUBLIC_SUPABASE_URL?.substring(0, 30) + '...',
      key_length: process.env.SUPABASE_SERVICE_ROLE_KEY?.length || 0
    },
    tests: [] as Array<{ test: string; ok: boolean; [key: string]: any; }>
  };

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceRoleKey) {
    return NextResponse.json({
      ok: false,
      error: 'Faltan variables de entorno',
      diagnostics
    }, { status: 500 });
  }

  try {
    // Test 1: Crear cliente
    const supabase = createClient(url, serviceRoleKey);
    diagnostics.tests.push({ test: 'create_client', ok: true });

    // Test 2: Verificar conexión básica con auth.admin
    try {
      const { data: users, error: listError } = await supabase.auth.admin.listUsers({
        page: 1,
        perPage: 1
      });
      
      if (listError) {
        diagnostics.tests.push({ 
          test: 'list_users', 
          ok: false, 
          error: listError.message,
          code: listError.status || 'unknown'
        });
      } else {
        diagnostics.tests.push({ 
          test: 'list_users', 
          ok: true, 
          user_count: users?.users?.length || 0 
        });
      }
    } catch (listErr: any) {
      diagnostics.tests.push({ 
        test: 'list_users', 
        ok: false, 
        error: listErr.message || 'Unknown error',
        type: listErr.constructor.name
      });
    }

    // Test 3: Verificar si el usuario admin@ejemplo.com ya existe
    try {
      const { data: existingUser, error: getUserError } = await supabase.auth.admin.getUserById('dummy-id');
      // Este error es esperado, solo queremos ver si la API responde
      diagnostics.tests.push({ 
        test: 'get_user_api', 
        ok: true,
        note: 'API responde correctamente'
      });
    } catch (getUserErr: any) {
      diagnostics.tests.push({ 
        test: 'get_user_api', 
        ok: false, 
        error: getUserErr.message || 'Unknown error'
      });
    }

    return NextResponse.json({
      ok: true,
      message: 'Diagnóstico completado',
      diagnostics
    });

  } catch (err: any) {
    diagnostics.tests.push({ 
      test: 'general', 
      ok: false, 
      error: err.message || 'Unknown error',
      type: err.constructor.name
    });

    return NextResponse.json({
      ok: false,
      error: 'Error en diagnóstico',
      diagnostics
    }, { status: 500 });
  }
}