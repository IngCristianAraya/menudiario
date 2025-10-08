# Integración de Landing Page con Panel de Administración

## 1. Configuración Inicial

### Variables de Entorno
```env
NEXT_PUBLIC_ADMIN_URL=https://admin.turestaurante.com
NEXT_PUBLIC_API_URL=https://api.turestaurante.com
```

## 2. Componentes Compartidos

### Botón de Acceso
```tsx
// components/shared/AdminButton.tsx
import Link from 'next/link'

export function AdminButton() {
  return (
    <Link 
      href={process.env.NEXT_PUBLIC_ADMIN_URL!}
      className="bg-primary text-white px-6 py-2 rounded-lg hover:bg-primary/90 transition"
    >
      Acceso Administrativo
    </Link>
  )
}
```

## 3. API Routes para Datos Compartidos

### Obtener Menú del Día
```typescript
// app/api/menu/route.ts
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export async function GET() {
  const supabase = createRouteHandlerClient({ cookies })
  
  const { data: menu, error } = await supabase
    .from('menus')
    .select('*')
    .eq('activo', true)
    .order('categoria')

  if (error) {
    return new Response(JSON.stringify({ error }), { status: 500 })
  }

  return new Response(JSON.stringify(menu), {
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'public, s-maxage=3600'
    }
  })
}
```

## 4. Sincronización de Datos

### Webhooks para Actualización en Tiempo Real
```typescript
// app/api/webhooks/menu-update/route.ts
import { NextResponse } from 'next/server'
import { revalidatePath } from 'next/cache'

export async function POST() {
  try {
    revalidatePath('/')
    revalidatePath('/menu')
    return NextResponse.json({ revalidated: true, now: Date.now() })
  } catch (err) {
    return NextResponse.json({ error: 'Error al revalidar' }, { status: 500 })
  }
}
```

## 5. Seguridad

### Middleware de Autenticación
```typescript
// middleware.ts
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('auth-token')
  const isAdminPath = request.nextUrl.pathname.startsWith('/admin')

  if (isAdminPath && !token) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}
```

## 6. Despliegue

### Configuración de Dominios
- `turestaurante.com` → Landing Page
- `admin.turestaurante.com` → Panel de Administración
- `api.turestaurante.com` → API Pública

### Variables de Entorno de Producción
```env
NEXT_PUBLIC_SUPABASE_URL=tu_url_produccion
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_key_publica
SUPABASE_SERVICE_ROLE_KEY=tu_key_privada
NEXT_PUBLIC_ADMIN_URL=https://admin.turestaurante.com
```
