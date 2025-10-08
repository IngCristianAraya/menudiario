# Guía de Estilo

## Convenciones de Código

### Nombrado
- **Componentes**: `PascalCase` (ej: `PedidoForm.tsx`)
- **Archivos**: `kebab-case` (ej: `pedido-form.tsx`)
- **Variables y funciones**: `camelCase`
- **Constantes**: `UPPER_SNAKE_CASE`
- **Tipos/Interfaces**: `PascalCase` con prefijo `I` (opcional)

### Estructura de Componentes

```typescript
// 1. Importaciones
import React from 'react';

// 2. Tipos
interface IProps {
  // props aquí
}

// 3. Componente
export const MiComponente: React.FC<IProps> = () => {
  // 4. Hooks
  // 5. Lógica
  
  // 6. Render
  return (
    <div>
      {/* Contenido */}
    </div>
  );
};
```

## Estilos con Tailwind CSS

### Clases de Utilidad
```jsx
// Bueno
<button className="px-4 py-2 bg-blue-500 text-white rounded-lg">
  Botón
</button>

// Evitar estilos en línea
<button style={{ padding: '0.5rem 1rem', backgroundColor: 'blue' }}>
  Botón
</button>
```

### Componentes con @apply
```css
/* styles/Button.module.css */
.btn-primary {
  @apply px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600;
}
```

## Convenciones de Git

### Mensajes de Commit
```
tipo(ámbito): descripción breve

Descripción detallada si es necesario

[OPCIONAL: Enlaces a issues o notas]
```

**Tipos de commit**:
- `feat`: Nueva característica
- `fix`: Corrección de errores
- `docs`: Cambios en la documentación
- `style`: Cambios de formato (punto y coma, indentación, etc.)
- `refactor`: Cambios que no corrigen errores ni agregan características
- `test`: Adición o modificación de pruebas
- `chore`: Actualización de tareas de construcción, configuración, etc.

### Ejemplo
```
feat(pedidos): agregar filtro por fecha

Se agregó un nuevo componente DateRangePicker para filtrar pedidos por rango de fechas.

Close #123
```

## Estructura de Carpetas

```
components/
  common/          # Componentes genéricos reutilizables
  features/        # Componentes específicos de características
  layouts/         # Componentes de diseño
  ui/              # Componentes de interfaz de usuario
```

## Pruebas

### Convenciones de Nombrado
```
ComponentName/
  ComponentName.tsx
  ComponentName.test.tsx
  ComponentName.stories.tsx
  index.ts
```

### Ejemplo de Prueba
```typescript
describe('ComponentName', () => {
  it('debe renderizar correctamente', () => {
    // Arrange
    // Act
    // Assert
  });
});
```

## Documentación

### Comentarios de Documentación
```typescript
/**
 * Calcula el total de un pedido
 * @param items - Array de ítems del pedido
 * @returns Total numérico con 2 decimales
 */
function calculateTotal(items: IItem[]): number {
  // ...
}
```

### Historias de Storybook
```typescript
export default {
  title: 'Components/Button',
  component: Button,
};

export const Primary = () => <Button variant="primary">Click</Button>;
```

## Accesibilidad

### Elementos Interactivos
```jsx
// Bueno
<button 
  onClick={handleClick}
  aria-label="Cerrar menú"
>
  <XIcon />
</button>

// Mejor (si solo hay un icono)
<IconButton 
  icon={<XIcon />}
  label="Cerrar menú"
  onClick={handleClick}
/>
```

### Imágenes
```jsx
<Image
  src="/logo.png"
  alt="Logo de la aplicación"
  width={120}
  height={40}
  priority
/>
```

## Rendimiento

### Carga Diferida
```jsx
const HeavyComponent = dynamic(
  () => import('../components/HeavyComponent'),
  { loading: () => <p>Cargando...</p> }
);
```

### Memoización
```jsx
const MemoizedComponent = React.memo(ExpensiveComponent);
```

## Internacionalización

### Uso de Traducciones
```typescript
const { t } = useTranslation();

return (
  <h1>{t('welcome')}</h1>
);
```

### Estructura de Archivos de Traducción
```json
// locales/es/common.json
{
  "welcome": "Bienvenido",
  "actions": {
    "save": "Guardar",
    "cancel": "Cancelar"
  }
}
```
