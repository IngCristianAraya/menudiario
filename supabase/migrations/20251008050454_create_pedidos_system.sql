/*
  # Sistema Pedidos Diarios - Base de datos

  1. Nuevas Tablas
    - `menus_diarios`
      - `id` (uuid, primary key)
      - `nombre` (text) - Nombre del plato
      - `precio` (decimal) - Precio del plato
      - `emoji` (text) - Emoji visual del plato
      - `activo` (boolean) - Si está disponible hoy
      - `created_at` (timestamptz)
    
    - `pedidos_diarios`
      - `id` (uuid, primary key)
      - `tipo` (text) - 'local' o 'delivery'
      - `items` (jsonb) - Array de {plato_id, nombre, cantidad, precio}
      - `total` (decimal) - Total del pedido
      - `fecha` (date) - Fecha del pedido
      - `hora` (time) - Hora del pedido
      - `created_at` (timestamptz)

  2. Seguridad
    - Habilitar RLS en ambas tablas
    - Políticas públicas de lectura/escritura (app local sin auth)

  3. Notas importantes
    - Sistema optimizado para rapidez y simplicidad
    - Sin relaciones complejas para mantener velocidad
    - Ideal para pequeños negocios
*/

-- Crear tabla de menú diario
CREATE TABLE IF NOT EXISTS menus_diarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre text NOT NULL,
  precio decimal(10,2) NOT NULL DEFAULT 0,
  emoji text DEFAULT '🍽️',
  activo boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Crear tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos_diarios (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo text NOT NULL CHECK (tipo IN ('local', 'delivery')),
  items jsonb NOT NULL DEFAULT '[]'::jsonb,
  total decimal(10,2) NOT NULL DEFAULT 0,
  fecha date DEFAULT CURRENT_DATE,
  hora time DEFAULT CURRENT_TIME,
  created_at timestamptz DEFAULT now()
);

-- Habilitar RLS
ALTER TABLE menus_diarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos_diarios ENABLE ROW LEVEL SECURITY;

-- Políticas públicas (app sin autenticación)
CREATE POLICY "Acceso público a menú - SELECT"
  ON menus_diarios FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Acceso público a menú - INSERT"
  ON menus_diarios FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Acceso público a menú - UPDATE"
  ON menus_diarios FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Acceso público a pedidos - SELECT"
  ON pedidos_diarios FOR SELECT
  TO anon
  USING (true);

CREATE POLICY "Acceso público a pedidos - INSERT"
  ON pedidos_diarios FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "Acceso público a pedidos - UPDATE"
  ON pedidos_diarios FOR UPDATE
  TO anon
  USING (true)
  WITH CHECK (true);

CREATE POLICY "Acceso público a pedidos - DELETE"
  ON pedidos_diarios FOR DELETE
  TO anon
  USING (true);

-- Insertar datos de ejemplo para el menú
INSERT INTO menus_diarios (nombre, precio, emoji, activo) VALUES
  ('Hamburguesa Clásica', 12.50, '🍔', true),
  ('Pizza Margarita', 18.00, '🍕', true),
  ('Sándwich de Pollo', 10.00, '🥪', true),
  ('Papas Fritas', 5.50, '🍟', true),
  ('Ensalada César', 9.00, '🥗', true),
  ('Refresco', 3.50, '🥤', true),
  ('Café', 4.00, '☕', true),
  ('Postre del Día', 6.50, '🍰', true)
ON CONFLICT DO NOTHING;

-- Crear índices para optimizar consultas
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha ON pedidos_diarios(fecha);
CREATE INDEX IF NOT EXISTS idx_pedidos_tipo ON pedidos_diarios(tipo);
CREATE INDEX IF NOT EXISTS idx_menus_activo ON menus_diarios(activo);