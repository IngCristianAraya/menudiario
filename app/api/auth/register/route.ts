import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

function getSupabaseAdmin() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !service) {
    throw new Error('Faltan NEXT_PUBLIC_SUPABASE_URL o SUPABASE_SERVICE_ROLE_KEY')
  }
  return createClient(url, service, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })
}

export async function POST(request: Request) {
  try {
    const { name, email, password } = await request.json()

    // Validar los datos de entrada
    if (!name || !email || !password) {
      return NextResponse.json(
        { message: 'Todos los campos son obligatorios' },
        { status: 400 }
      )
    }

    const supabase = getSupabaseAdmin()
    // Registrar al usuario en Supabase Auth
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: name,
        },
      },
    })

    if (authError) {
      console.error('Error al registrar el usuario:', authError)
      return NextResponse.json(
        { message: 'Error al registrar el usuario', error: authError.message },
        { status: 400 }
      )
    }

    // Crear el perfil del usuario en la base de datos
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .insert([
        {
          id: authData.user?.id,
          email,
          full_name: name,
          role: 'user', // Rol por defecto
        },
      ])
      .select()

    if (profileError) {
      console.error('Error al crear el perfil:', profileError)
      // Si falla la creación del perfil, eliminamos el usuario de auth para mantener la consistencia
      await supabase.auth.admin.deleteUser(authData.user?.id!)
      
      return NextResponse.json(
        { message: 'Error al crear el perfil del usuario', error: profileError.message },
        { status: 500 }
      )
    }

    return NextResponse.json(
      { message: 'Usuario registrado exitosamente', user: profileData[0] },
      { status: 201 }
    )
  } catch (error) {
    console.error('Error en el servidor:', error)
    return NextResponse.json(
      { message: 'Error interno del servidor' },
      { status: 500 }
    )
  }
}

export async function GET() {
  return NextResponse.json(
    { message: 'Método no permitido' },
    { status: 405 }
  )
}
