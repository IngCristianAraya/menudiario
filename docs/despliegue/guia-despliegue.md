# Guía de Despliegue

## Requisitos Previos
- Node.js 16+ instalado
- Cuenta en Vercel o servicio de hosting
- Base de datos Supabase configurada
- Variables de entorno configuradas

## Pasos para el Despliegue

### 1. Configuración del Entorno
```bash
# Clonar el repositorio
git clone [URL_DEL_REPOSITORIO]
cd proyecto

# Instalar dependencias
npm install

# Configurar variables de entorno
cp .env.example .env.local
# Editar .env.local con sus credenciales
```

### 2. Despliegue en Vercel
1. Conectar su repositorio de GitHub/GitLab a Vercel
2. Configurar las variables de entorno en la configuración del proyecto
3. Establecer el framework como Next.js
4. Configurar el comando de construcción: `npm run build`
5. Especificar el directorio de salida: `.next`
6. Desplegar

### 3. Configuración de Dominio Personalizado
1. Ir a la configuración de dominios en Vercel
2. Añadir su dominio personalizado
3. Configurar los registros DNS según las instrucciones

### 4. Configuración de SSL
El certificado SSL se configura automáticamente en Vercel. Verifique que esté activo en la configuración del dominio.

## Variables de Entorno Requeridas

```
NEXT_PUBLIC_SUPABASE_URL=su_url_de_supabase
NEXT_PUBLIC_SUPABASE_ANON_KEY=su_clave_anonima_de_supabase
# Otras variables de entorno específicas de la aplicación
```

## Monitoreo y Mantenimiento
- Revisar los logs de la aplicación regularmente
- Configurar alertas de errores
- Realizar copias de seguridad periódicas
- Mantener las dependencias actualizadas

## Actualizaciones
1. Hacer pull de los últimos cambios
2. Probar localmente
3. Desplegar en el entorno de staging (si aplica)
4. Desplegar en producción

## Rollback
En caso de problemas, puede volver a un despliegue anterior desde el panel de Vercel.
