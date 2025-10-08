# Instalación del Proyecto

## Requisitos Previos
- Node.js 18 o superior
- npm 9 o superior
- Cuenta en Supabase

## Pasos de Instalación

### 1. Clonar el Repositorio
```bash
git clone https://github.com/tu-usuario/gestor-pedidos.git
cd gestor-pedidos
```

### 2. Instalar Dependencias
```bash
npm install
# o
yarn
# o
pnpm install
```

### 3. Configurar Variables de Entorno
Crea un archivo `.env.local` en la raíz del proyecto:

```env
# Supabase
NEXT_PUBLIC_SUPABASE_URL=tu_url_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anonima

# Entorno
NODE_ENV=development
```

### 4. Iniciar el Servidor de Desarrollo
```bash
npm run dev
# o
yarn dev
# o
pnpm dev
```

El servidor estará disponible en [http://localhost:3000](http://localhost:3000)

## Configuración de la Base de Datos

### 1. Crear Proyecto en Supabase
1. Ve a [app.supabase.com](https://app.supabase.com)
2. Crea un nuevo proyecto
3. Ve a Project Settings > API y copia las credenciales

### 2. Ejecutar Migraciones
```bash
npx supabase migration up
```

### 3. Poblar Datos Iniciales
```bash
npx supabase db seed
```

## Solución de Problemas Comunes

### Error: No se pueden encontrar las variables de entorno
- Verifica que el archivo `.env.local` exista en la raíz del proyecto
- Asegúrate de que los nombres de las variables coincidan exactamente
- Reinicia el servidor después de hacer cambios en las variables de entorno

### Error de Conexión a Supabase
- Verifica que la URL y la clave anónima sean correctas
- Asegúrate de que el proyecto Supabase esté activo
- Verifica la configuración de red y firewalls
