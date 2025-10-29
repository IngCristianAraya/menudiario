import { createClient } from '@supabase/supabase-js'

export type TenantSecrets = {
  url: string
  anonKey?: string
  serviceRole?: string
}

export function extractSubdomainFromHost(host?: string, rootDomain?: string): string | null {
  if (!host) return null
  const cleanHost = host.toLowerCase().split(':')[0]
  const domain = (rootDomain || process.env.NEXT_PUBLIC_ROOT_DOMAIN || '').toLowerCase()
  if (!domain) return null
  if (cleanHost === domain || cleanHost === `www.${domain}`) return 'menudiario'
  if (cleanHost.endsWith(`.${domain}`)) {
    const parts = cleanHost.split('.')
    return parts.slice(0, parts.length - domain.split('.').length).join('.') || null
  }
  return null
}

export function getTenantSecrets(subdomain: string): TenantSecrets {
  const url = process.env[`SUPABASE_URL__${subdomain}`]
  const anonKey = process.env[`SUPABASE_ANON_KEY__${subdomain}`]
  const serviceRole = process.env[`SUPABASE_SERVICE_ROLE__${subdomain}`]
  if (!url) {
    throw new Error(`SUPABASE_URL__${subdomain} no configurado`)
  }
  return { url, anonKey, serviceRole }
}

export function getTenantSupabaseClientFromEnv(subdomain: string) {
  const { url, anonKey } = getTenantSecrets(subdomain)
  if (!anonKey) {
    throw new Error(`SUPABASE_ANON_KEY__${subdomain} no configurado`)
  }
  return createClient(url, anonKey)
}

export function getTenantSupabaseAdminFromEnv(subdomain: string) {
  const { url, serviceRole } = getTenantSecrets(subdomain)
  if (!serviceRole) {
    throw new Error(`SUPABASE_SERVICE_ROLE__${subdomain} no configurado`)
  }
  return createClient(url, serviceRole, { auth: { autoRefreshToken: false, persistSession: false } })
}