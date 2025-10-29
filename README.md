# Gestor de Pedidos - Sistema de Menú Digital

Aplicación móvil para gestión de pedidos en restaurantes, con panel de administración y landing page.

## Características Principales
- Toma de pedidos en tiempo real
- Gestión de menú diario
- Reportes de ventas
- Panel de administración

## Estructura del Proyecto
```
project/
├── app/                    # Next.js app router
│   ├── admin/              # Panel de administración
│   ├── menu/               # Vista de menú para clientes
│   └── api/                # Endpoints de la API
├── components/             # Componentes reutilizables
├── lib/                    # Utilidades y configuraciones
└── public/                 # Archivos estáticos
```

## Configuración Inicial

### 1. Variables de Entorno
Crea un archivo `.env.local` en la raíz con:

```env
NEXT_PUBLIC_SUPABASE_URL=tu_url_de_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anonima
```

### 2. Instalación de Dependencias
```bash
npm install
# o
yarn
```

### 3. Ejecutar en Desarrollo
```bash
npm run dev
# o
yarn dev
```

## Configuración de Supabase

### 1. Crear Proyecto en Supabase
1. Ve a [app.supabase.com](https://app.supabase.com)
2. Crea un nuevo proyecto
3. Ve a Project Settings > API y copia las credenciales

### 2. Configurar Tablas Necesarias

```sql
-- Tabla de menús
create table menus (
  id uuid default uuid_generate_v4() primary key,
  nombre varchar(100) not null,
  descripcion text,
  precio numeric(10,2) not null,
  categoria varchar(50) not null,
  activo boolean default true,
  imagen_url text,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Tabla de pedidos
create table pedidos (
  id uuid default uuid_generate_v4() primary key,
  cliente_id uuid references auth.users,
  tipo_pedido varchar(20) not null,
  total numeric(10,2) not null,
  estado varchar(20) default 'pendiente',
  detalles jsonb not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Habilitar RLS (Row Level Security)
alter table menus enable row level security;
alter table pedidos enable row level security;
```

## Despliegue

### Vercel (Recomendado)
1. Conecta tu repositorio a Vercel
2. Configura las variables de entorno
3. Ejecuta el despliegue

## Scripts Disponibles
- `dev`: Inicia el servidor de desarrollo
- `build`: Construye la aplicación para producción
- `start`: Inicia el servidor de producción
- `lint`: Ejecuta el linter
## Estado actual y cómo funciona (multitenant)

- Entorno de desarrollo: servidor activo en `http://localhost:3001/`.
- Dominio raíz local: `NEXT_PUBLIC_ROOT_DOMAIN=lvh.me` para simular subdominios (`*.lvh.me` → `127.0.0.1`).
- Resolución de tenant:
  - Se obtiene el subdominio desde el `host` (ej. `lasazoncriollamenu.lvh.me`).
  - El frontend consulta la tabla `public.tenants`.
  - El código soporta ambos esquemas de columnas:
    - Inglés: `name`, `subdomain`, `is_active`, `config`.
    - Español: `nombre`, `subdominio`, `activo`, `configuracion`.
- Credenciales de Supabase por tenant: si existen variables `SUPABASE_URL__<subdomain>`, `SUPABASE_ANON_KEY__<subdomain>`, se usan; si no, se hace fallback a las globales `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY`.

### Visualizar un tenant

1. Crear el tenant en Supabase (si no existe): usa `scripts/seed_tenant_lasazoncriolla.sql` en el SQL Editor.
2. Abrir `http://lasazoncriollamenu.lvh.me:3001` para probar el subdominio local.
3. Verificar por API: `GET /api/tenant/config` debe devolver `{ subdomain, url, anonKey }`.

### Notas

- El frontend se actualizó para ser tolerante a esquemas mixtos en `tenants`.
- Si cambias de esquema, mantén al menos `subdomain`/`subdominio` y estado `is_active`/`activo`.
