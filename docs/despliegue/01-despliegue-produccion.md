# Despliegue en Producción

## Requisitos Previos
- Cuenta en Vercel o plataforma de hosting
- Dominio configurado (opcional)
- Variables de entorno de producción

## Configuración en Vercel

### 1. Importar Proyecto
1. Inicia sesión en [Vercel](https://vercel.com)
2. Haz clic en "Import Project"
3. Conecta tu repositorio de GitHub/GitLab

### 2. Configuración del Proyecto
- **Framework**: Next.js
- **Build Command**: `npm run build` o `yarn build`
- **Output Directory**: `.next`
- **Install Command**: `npm install` o `yarn`

### 3. Variables de Entorno
Agrega las variables de entorno necesarias:

```env
NEXT_PUBLIC_SUPABASE_URL=tu_url_produccion
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anonima_produccion
NODE_ENV=production
```

### 4. Dominios Personalizados
1. Ve a Project Settings > Domains
2. Agrega tu dominio personalizado
3. Configura los registros DNS según las instrucciones

## Configuración de Entornos

### Variables por Entorno
| Variable                  | Desarrollo         | Producción           |
|---------------------------|--------------------|----------------------|
| `NEXT_PUBLIC_API_URL`     | http://localhost:3000 | https://api.ejemplo.com |
| `NEXT_PUBLIC_ANALYTICS_ID`| -                  | G-XXXXXXXXXX         |

## CI/CD con GitHub Actions

### Configuración Básica
Crea un archivo `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
      - run: npm test
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v20
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          working-directory: ./
          vercel-args: '--prod'
```

## Monitoreo del Despliegue

### Verificar Estado
1. Revisa los logs de construcción en Vercel
2. Verifica el estado en [Vercel Status](https://www.vercel-status.com/)
3. Monitorea el rendimiento en la pestaña "Analytics"

### Rollback
1. Ve a la pestaña "Deployments"
2. Encuentra la versión estable anterior
3. Haz clic en "Revert"

## Pruebas en Producción

### Smoke Tests
```javascript
// tests/smoke.js
describe('Smoke Test', () => {
  it('debe cargar la página principal', async () => {
    await page.goto(process.env.SITE_URL);
    expect(await page.title()).toContain('Gestor de Pedidos');
  });
});
```

### Pruebas de Carga
```yaml
# k6/load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '30s',
};

export default function () {
  const res = http.get('https://tu-sitio.com/api/pedidos');
  check(res, { 'status was 200': (r) => r.status == 200 });
  sleep(1);
}
```

## Seguridad en Producción

### Headers de Seguridad
```javascript
// next.config.js
const securityHeaders = [
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
  {
    key: 'X-Frame-Options',
    value: 'SAMEORIGIN',
  },
  {
    key: 'X-XSS-Protection',
    value: '1; mode=block',
  },
];

module.exports = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: securityHeaders,
      },
    ];
  },
};
```

### Monitoreo de Seguridad
1. Configura alertas de seguridad en Vercel
2. Monitorea vulnerabilidades con `npm audit`
3. Revisa registros de acceso sospechoso

## Escalado

### Opciones en Vercel
- **Hobby**: Hasta 100GB de ancho de banda
- **Pro**: Ancho de banda ilimitado, más regiones
- **Enterprise**: SLA, soporte prioritario

### Recomendaciones
- Habilita Auto-scaling
- Configura un CDN global
- Usa almacenamiento en caché

## Mantenimiento

### Actualizaciones
1. Programa ventanas de mantenimiento
2. Notifica a los usuarios con anticipación
3. Realiza copias de seguridad antes de actualizar

### Copias de Seguridad
- Base de datos: Diarias
- Archivos estáticos: Semanales
- Configuración: En cada cambio

## Solución de Problemas

### Errores Comunes
1. **Fallo en el Build**
   - Verifica los logs de construcción
   - Prueba localmente con `npm run build`

2. **Variables de Entorno**
   - Verifica que todas las variables estén configuradas
   - Reinicia el despliegue después de cambios

3. **Rendimiento Lento**
- Revisa métricas en Vercel Analytics
- Optimiza imágenes y recursos estáticos
- Considera usar ISR o SSG

## Recursos Adicionales
- [Documentación de Vercel](https://vercel.com/docs)
- [Guía de Rendimiento de Next.js](https://nextjs.org/docs/basic-features/performance)
- [Mejores Prácticas de Seguridad](https://owasp.org/www-project-top-ten/)
