import { NextResponse } from 'next/server'
import { extractSubdomainFromHost, getTenantSecrets } from '@/lib/supabase/tenant'

export async function GET(req: Request) {
  try {
    const host = req.headers.get('host') || ''
    const subdomain = extractSubdomainFromHost(host, process.env.NEXT_PUBLIC_ROOT_DOMAIN) || 'menudiario'

    // Intentar obtener credenciales específicas del tenant
    try {
      const { url, anonKey } = getTenantSecrets(subdomain)
      if (!anonKey) throw new Error('Anon key faltante')
      return NextResponse.json({ subdomain, url, anonKey })
    } catch {
      // Fallback a variables globales (preview/local)
      const url = process.env.NEXT_PUBLIC_SUPABASE_URL
      const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
      if (!url || !anonKey) {
        return NextResponse.json({ error: 'Config Supabase no disponible' }, { status: 500 })
      }
      return NextResponse.json({ subdomain, url, anonKey, fallback: true })
    }
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || 'Error obteniendo config' }, { status: 500 })
  }
}