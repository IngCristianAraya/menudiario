import { createClient } from '@supabase/supabase-js'
import { NextResponse } from 'next/server'

export async function GET() {
  try {
    // Helper para crear cliente Supabase (admin o anónimo)
    const makeClient = (admin: boolean) =>
      createClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        admin
          ? process.env.SUPABASE_SERVICE_ROLE_KEY!
          : process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
        {
          auth: {
            autoRefreshToken: false,
            persistSession: false,
            detectSessionInUrl: false,
          },
        }
      )

    // Cliente admin para consultas de auditoría
    const supabase = makeClient(true)
    
    const results = {
      timestamp: new Date().toISOString(),
      tenant_focus: 'La Sazón Criolla',
      checks: {} as any,
      security_alerts: [] as string[],
      deployment_status: 'unknown' as 'ready' | 'needs_setup' | 'has_issues' | 'unknown',
      recommendations: [] as string[]
    }

    // 1. Contar filas en tablas activas
    const activeTables = ['restaurantes', 'perfiles_usuarios', 'platos', 'pedidos', 'items_pedido', 'tenants', 'tenant_users', 'categorias_platos']
    
    for (const table of activeTables) {
      try {
        const { count, error } = await supabase
          .from(table)
          .select('*', { count: 'exact', head: true })
        
        results.checks[`${table}_count`] = error ? `Error: ${error.message}` : count
      } catch (err) {
        results.checks[`${table}_count`] = `Exception: ${err}`
      }
    }

    // 2. Verificar tenant "La Sazón Criolla" específicamente
    try {
      const { data: sazoncriolla } = await supabase
        .from('tenants')
        .select('*')
        .eq('slug', 'lasazoncriollamenu')
        .single()
      
      if (sazoncriolla) {
        results.checks.sazon_criolla_tenant = {
          found: true,
          id: sazoncriolla.id,
          name: sazoncriolla.name,
          active: sazoncriolla.is_active,
          slug: sazoncriolla.slug
        }
        
        // Verificar restaurante vinculado
        const { data: restaurant } = await supabase
          .from('restaurantes')
          .select('*')
          .eq('tenant_id', sazoncriolla.id)
          .single()
        
        if (restaurant) {
          results.checks.sazon_criolla_restaurant = {
            found: true,
            id: restaurant.id,
            name: restaurant.nombre,
            active: restaurant.activo,
            slug: restaurant.slug
          }
          
          // Verificar admin del restaurante
          const { data: admin } = await supabase
            .from('perfiles_usuarios')
            .select('*')
            .eq('restaurante_id', restaurant.id)
            .eq('rol', 'admin')
            .single()
          
          results.checks.sazon_criolla_admin = {
            found: !!admin,
            name: admin ? `${admin.nombre} ${admin.apellido || ''}`.trim() : null,
            email: admin ? 'Configurado' : 'No encontrado'
          }
          
          // Contar platos y categorías
          const { count: platosCount } = await supabase
            .from('platos')
            .select('*', { count: 'exact', head: true })
            .eq('restaurante_id', restaurant.id)
            .eq('activo', true)
          
          const { count: categoriasCount } = await supabase
            .from('categorias_platos')
            .select('*', { count: 'exact', head: true })
            .eq('restaurante_id', restaurant.id)
            .eq('activo', true)
          
          results.checks.sazon_criolla_menu = {
            categorias: categoriasCount || 0,
            platos_activos: platosCount || 0,
            menu_ready: (categoriasCount || 0) > 0 && (platosCount || 0) > 0
          }
          
        } else {
          results.checks.sazon_criolla_restaurant = { found: false }
          results.security_alerts.push('Tenant La Sazón Criolla existe pero no tiene restaurante vinculado')
        }
        
      } else {
        results.checks.sazon_criolla_tenant = { found: false }
        results.security_alerts.push('Tenant La Sazón Criolla no encontrado')
      }
    } catch (err) {
      results.checks.sazon_criolla_tenant = `Error: ${err}`
    }

    // 3. Detectar columna identificadora en tenants
    try {
      const { data: tenantSample } = await supabase
        .from('tenants')
        .select('*')
        .limit(1)
        .single()
      
      if (tenantSample) {
        const hasSlug = 'slug' in tenantSample
        const hasSubdomain = 'subdomain' in tenantSample
        const hasSubdominio = 'subdominio' in tenantSample
        
        results.checks.tenant_identifier = {
          has_slug: hasSlug,
          has_subdomain: hasSubdomain,
          has_subdominio: hasSubdominio,
          recommended: hasSlug ? 'slug' : hasSubdomain ? 'subdomain' : hasSubdominio ? 'subdominio' : 'unknown'
        }
      }
    } catch (err) {
      results.checks.tenant_identifier = `Error: ${err}`
    }

    // 4. Verificar tenant_id en restaurantes
    try {
      const { data: restauranteSample } = await supabase
        .from('restaurantes')
        .select('tenant_id')
        .limit(1)
        .single()
      
      results.checks.restaurantes_has_tenant_id = restauranteSample && 'tenant_id' in restauranteSample
    } catch (err) {
      results.checks.restaurantes_has_tenant_id = `Error: ${err}`
    }

    // 5. Smoke test RLS - intentar leer como anónimo
    try {
      const anonSupabase = makeClient(false)
      
      const rlsTests = ['restaurantes', 'platos', 'pedidos', 'tenants']
      const rlsResults = {} as any
      
      for (const table of rlsTests) {
        try {
          const { data, error } = await anonSupabase
            .from(table)
            .select('id')
            .limit(1)
          
          const accessible = !error && data && data.length > 0
          
          rlsResults[table] = {
            accessible,
            error: error?.message || null,
            data_count: data?.length || 0
          }
          
          // Alertas de seguridad
          if (accessible && table !== 'platos' && table !== 'restaurantes') {
            results.security_alerts.push(`ALERTA: Tabla ${table} accesible anónimamente`)
          }
          
        } catch (err) {
          rlsResults[table] = { accessible: false, error: `Exception: ${err}` }
        }
      }
      
      results.checks.rls_anonymous_access = rlsResults
    } catch (err) {
      results.checks.rls_anonymous_access = `Error: ${err}`
    }

    // 6. Verificar políticas inseguras conocidas
    try {
      const { data: policies } = await supabase.rpc('sql', {
        query: `
          SELECT tablename, policyname, cmd, qual, with_check 
          FROM pg_policies 
          WHERE schemaname = 'public' 
          AND (qual LIKE '%auth.uid() IS NULL%' OR with_check LIKE '%auth.uid() IS NULL%')
          ORDER BY tablename, policyname
        `
      })
      
      if (policies && policies.length > 0) {
        results.checks.insecure_policies = policies
        results.security_alerts.push(`Encontradas ${policies.length} políticas con acceso anónimo (OR auth.uid() IS NULL)`)
      } else {
        results.checks.insecure_policies = []
      }
    } catch (err) {
      results.checks.insecure_policies = `Error: ${err}`
    }

    // 7. Determinar estado del despliegue
    const sazoncriollaTenant = results.checks.sazon_criolla_tenant
    const sazoncriollRestaurant = results.checks.sazon_criolla_restaurant
    const sazoncriollAdmin = results.checks.sazon_criolla_admin
    const sazoncriollMenu = results.checks.sazon_criolla_menu
    
    if (sazoncriollaTenant?.found && sazoncriollRestaurant?.found && sazoncriollAdmin?.found && sazoncriollMenu?.menu_ready) {
      if (results.security_alerts.length === 0) {
        results.deployment_status = 'ready'
      } else {
        results.deployment_status = 'has_issues'
      }
    } else if (sazoncriollaTenant?.found) {
      results.deployment_status = 'needs_setup'
    } else {
      results.deployment_status = 'unknown'
    }

    // 8. Muestras de datos
    try {
      const { data: tenants } = await supabase
        .from('tenants')
        .select('id, name, slug, is_active')
        .limit(5)
      
      const { data: restaurantes } = await supabase
        .from('restaurantes')
        .select('id, nombre, slug, tenant_id, activo')
        .limit(5)
      
      results.checks.samples = {
        tenants: tenants || [],
        restaurantes: restaurantes || []
      }
    } catch (err) {
      results.checks.samples = `Error: ${err}`
    }

    // 9. Recomendaciones
    results.recommendations = []
    
    if (results.deployment_status === 'needs_setup') {
      results.recommendations.push('Ejecutar scripts/seed_legacy_demo.sql para crear datos iniciales')
    }
    
    if (results.security_alerts.length > 0) {
      results.recommendations.push('Ejecutar scripts/secure_legacy_policies.sql para endurecer seguridad')
    }
    
    if (results.deployment_status === 'ready') {
      results.recommendations.push('Tenant listo para producción')
      results.recommendations.push('Probar URL: /?tenant=lasazoncriollamenu')
    }

    return NextResponse.json(results)
    
  } catch (error) {
    console.error('Audit error:', error)
    return NextResponse.json(
      { error: 'Failed to perform audit', details: error },
      { status: 500 }
    )
  }
}