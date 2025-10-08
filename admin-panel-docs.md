# Documentación del Panel de Administración

## Estructura del Proyecto
```
admin-panel/
├── app/
│   ├── (auth)/
│   │   ├── login/
│   │   └── forgot-password/
│   ├── dashboard/
│   ├── menu/
│   ├── orders/
│   └── settings/
├── components/
│   ├── layout/
│   ├── ui/
│   └── shared/
└── lib/
```

## Configuración de Supabase

### 1. Variables de Entorno
```env
NEXT_PUBLIC_SUPABASE_URL=tu_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_key
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key
```

### 2. Inicialización del Cliente
```typescript
// lib/supabase/admin.ts
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY!

export const supabaseAdmin = createClient(supabaseUrl, supabaseKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})
```

## Integración con el Sistema de Gestión

### 1. Webhooks
Configura webhooks en Supabase para actualizar la UI en tiempo real:

```typescript
// app/api/webhooks/order-update/route.ts
export async function POST(req: Request) {
  const payload = await req.json()
  // Lógica para actualizar pedidos
}
```

### 2. Autenticación
```typescript
// middleware.ts
import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'

export async function middleware(req: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient({ req, res })
  
  const { data: { session } } = await supabase.auth.getSession()
  
  if (!session && req.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', req.url))
  }
  
  return res
}
```

## Seguridad
- Validación de roles en el servidor
- RLS (Row Level Security) en Supabase
- Protección de rutas API
- Monitoreo de actividad sospechosa

## Despliegue
1. Configurar variables de entorno en producción
2. Habilitar SSL
3. Configurar política de CORS
4. Establecer límites de tasa (rate limiting)

## Mantenimiento
- Actualizaciones regulares de dependencias
- Copias de seguridad diarias
- Monitoreo de rendimiento
- Pruebas de seguridad periódicas
