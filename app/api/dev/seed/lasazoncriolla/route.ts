import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

export async function POST() {
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json(
      {
        ok: false,
        error: 'Faltan variables de entorno: NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY',
      },
      { status: 500 }
    );
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    }
  );

  const TENANT_NAME = 'La sazón criolla';
  const TENANT_SUBDOMAIN = 'lasazoncriollamenu';

  try {
    // Detectar columnas disponibles en la tabla tenants
    let subKey: 'subdomain' | 'slug' | 'subdominio' = 'subdomain';
    let nameKey: 'name' | 'nombre' = 'name';
    let activeKey: 'is_active' | 'activo' = 'is_active';
    let hasContactEmail = false;

    const testSub = await supabase.from('tenants').select('id,subdomain').limit(1);
    if (testSub.error) {
      const testSlug = await supabase.from('tenants').select('id,slug').limit(1);
      if (!testSlug.error) {
        subKey = 'slug';
      } else {
        const testSubEs = await supabase.from('tenants').select('id,subdominio').limit(1);
        if (!testSubEs.error) {
          subKey = 'subdominio';
        } else {
          return NextResponse.json({ ok: false, step: 'detect_subdomain', error: 'No se encuentran columnas subdomain/slug/subdominio en tenants' }, { status: 500 });
        }
      }
    }

    const testName = await supabase.from('tenants').select('id,name').limit(1);
    if (testName.error) {
      const testNombre = await supabase.from('tenants').select('id,nombre').limit(1);
      if (!testNombre.error) {
        nameKey = 'nombre';
      } else {
        return NextResponse.json({ ok: false, step: 'detect_name', error: 'No se encuentran columnas name/nombre en tenants' }, { status: 500 });
      }
    }

    const testActive = await supabase.from('tenants').select('id,is_active').limit(1);
    if (testActive.error) {
      const testActivo = await supabase.from('tenants').select('id,activo').limit(1);
      if (!testActivo.error) {
        activeKey = 'activo';
      } else {
        return NextResponse.json({ ok: false, step: 'detect_active', error: 'No se encuentran columnas is_active/activo en tenants' }, { status: 500 });
      }
    }

    const testContactEmail = await supabase.from('tenants').select('id,contact_email').limit(1);
    if (!testContactEmail.error) {
      hasContactEmail = true;
    }

    // 1) Upsert del tenant según el esquema detectado
    const insertObj: Record<string, any> = {};
    insertObj[nameKey] = TENANT_NAME;
    insertObj[subKey] = TENANT_SUBDOMAIN;
    insertObj[activeKey] = true;
    if (hasContactEmail) {
      insertObj['contact_email'] = 'admin@lasazoncriolla.com';
    }

    const { data: tenant, error: tenantErr } = await supabase
      .from('tenants')
      .upsert(insertObj, { onConflict: subKey })
      .select()
      .single();

    if (tenantErr) {
      return NextResponse.json({ ok: false, step: 'upsert_tenant', error: tenantErr.message }, { status: 500 });
    }

    // 2) Vincular restaurante al tenant
    const { data: restaurantes, error: restErr } = await supabase
      .from('restaurantes')
      .update({ tenant_id: tenant.id })
      .or(`slug.eq.lasazoncriolla,nombre.eq.${encodeURIComponent(TENANT_NAME)}`)
      .select();

    if (restErr) {
      return NextResponse.json({ ok: false, step: 'link_restaurant', error: restErr.message }, { status: 500 });
    }

    return NextResponse.json({ ok: true, tenant, restaurantes });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message ?? 'Error desconocido' }, { status: 500 });
  }
}

export async function GET() {
  // Permite verificar rápidamente el estado del tenant
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE_KEY) {
    return NextResponse.json(
      {
        ok: false,
        error: 'Faltan variables de entorno: NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY',
      },
      { status: 500 }
    );
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
        detectSessionInUrl: false,
      },
    }
  );

  const TENANT_SUBDOMAIN = 'lasazoncriollamenu';

  const { data, error } = await supabase
    .from('tenants')
    .select('id,name,subdomain,is_active,created_at,updated_at')
    .eq('subdomain', TENANT_SUBDOMAIN)
    .maybeSingle();

  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }
  return NextResponse.json({ ok: true, tenant: data ?? null });
}