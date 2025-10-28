import { NextResponse } from 'next/server'
import { getTenantSupabaseAdminFromEnv } from '@/lib/supabase/tenant'

export async function POST(req: Request, { params }: { params: { subdomain: string } }) {
  try {
    const { email, password } = await req.json()
    if (!email || !password) {
      return NextResponse.json({ error: 'email y password requeridos' }, { status: 400 })
    }

    const supabaseAdmin = getTenantSupabaseAdminFromEnv(params.subdomain)
    const { data, error } = await supabaseAdmin.auth.admin.createUser({
      email,
      password,
      email_confirm: true
    })

    if (error) return NextResponse.json({ error: error.message }, { status: 400 })
    return NextResponse.json({ user: data.user })
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || 'Error creando usuario' }, { status: 500 })
  }
}