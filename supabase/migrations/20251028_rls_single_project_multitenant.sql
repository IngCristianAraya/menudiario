-- Multi-tenant en un solo proyecto Supabase
-- Aislamiento lógico por restaurante (tenant) usando RLS

-- 1) Habilitar RLS en tablas clave
ALTER TABLE IF EXISTS public.perfiles_usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.restaurantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.platos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.items_pedido ENABLE ROW LEVEL SECURITY;

-- 2) Agregar columnas de restaurante si faltan (para tablas diarias)
DO $$
BEGIN
  -- menus_diarios: sólo si la tabla existe
  IF to_regclass('public.menus_diarios') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'menus_diarios' AND column_name = 'restaurante_id'
    ) THEN
      ALTER TABLE public.menus_diarios ADD COLUMN restaurante_id uuid;
    END IF;
    CREATE INDEX IF NOT EXISTS idx_menus_diarios_restaurante ON public.menus_diarios(restaurante_id);
  END IF;

  -- pedidos_diarios: sólo si la tabla existe
  IF to_regclass('public.pedidos_diarios') IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.columns 
      WHERE table_schema = 'public' AND table_name = 'pedidos_diarios' AND column_name = 'restaurante_id'
    ) THEN
      ALTER TABLE public.pedidos_diarios ADD COLUMN restaurante_id uuid;
    END IF;
    CREATE INDEX IF NOT EXISTS idx_pedidos_diarios_restaurante ON public.pedidos_diarios(restaurante_id);
  END IF;
END $$;

ALTER TABLE IF EXISTS public.menus_diarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.pedidos_diarios ENABLE ROW LEVEL SECURITY;

-- 3) Políticas base: perfiles_usuarios (cada usuario ve/edita su perfil)
DROP POLICY IF EXISTS "pu_select_own" ON public.perfiles_usuarios;
DROP POLICY IF EXISTS "pu_update_own" ON public.perfiles_usuarios;

CREATE POLICY "pu_select_own" ON public.perfiles_usuarios
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "pu_update_own" ON public.perfiles_usuarios
  FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 4) Helper: condición de mismo restaurante
-- Se usa en varias políticas mediante subconsultas a perfiles_usuarios

-- 5) Restaurantes: lectura del restaurante propio; edición solo admin
DROP POLICY IF EXISTS "rest_select_own" ON public.restaurantes;
DROP POLICY IF EXISTS "rest_update_admin" ON public.restaurantes;

CREATE POLICY "rest_select_own" ON public.restaurantes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = restaurantes.id
    )
  );

CREATE POLICY "rest_update_admin" ON public.restaurantes
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = restaurantes.id AND pu.rol IN ('admin')
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = restaurantes.id AND pu.rol IN ('admin')
    )
  );

-- 6) Platos por restaurante
DROP POLICY IF EXISTS "platos_select_same_rest" ON public.platos;
DROP POLICY IF EXISTS "platos_write_admin" ON public.platos;

CREATE POLICY "platos_select_same_rest" ON public.platos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = platos.restaurante_id
    )
  );

CREATE POLICY "platos_write_admin" ON public.platos
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = platos.restaurante_id AND pu.rol IN ('admin')
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = platos.restaurante_id AND pu.rol IN ('admin')
    )
  );

-- 7) Pedidos por restaurante
DROP POLICY IF EXISTS "pedidos_select_same_rest" ON public.pedidos;
DROP POLICY IF EXISTS "pedidos_insert_same_rest" ON public.pedidos;
DROP POLICY IF EXISTS "pedidos_update_same_rest" ON public.pedidos;

CREATE POLICY "pedidos_select_same_rest" ON public.pedidos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos.restaurante_id
    )
  );

CREATE POLICY "pedidos_insert_same_rest" ON public.pedidos
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos.restaurante_id
    )
  );

CREATE POLICY "pedidos_update_same_rest" ON public.pedidos
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos.restaurante_id
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.perfiles_usuarios pu
      WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos.restaurante_id
    )
  );

-- 8) Ítems del pedido (derivan del pedido)
DROP POLICY IF EXISTS "items_select_same_rest" ON public.items_pedido;
DROP POLICY IF EXISTS "items_write_same_rest" ON public.items_pedido;

CREATE POLICY "items_select_same_rest" ON public.items_pedido
  FOR SELECT USING (
    EXISTS (
      SELECT 1
      FROM public.pedidos p
      JOIN public.perfiles_usuarios pu ON pu.restaurante_id = p.restaurante_id
      WHERE p.id = items_pedido.pedido_id AND pu.id = auth.uid()
    )
  );

CREATE POLICY "items_write_same_rest" ON public.items_pedido
  FOR ALL USING (
    EXISTS (
      SELECT 1
      FROM public.pedidos p
      JOIN public.perfiles_usuarios pu ON pu.restaurante_id = p.restaurante_id
      WHERE p.id = items_pedido.pedido_id AND pu.id = auth.uid()
    )
  ) WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.pedidos p
      JOIN public.perfiles_usuarios pu ON pu.restaurante_id = p.restaurante_id
      WHERE p.id = items_pedido.pedido_id AND pu.id = auth.uid()
    )
  );

-- 9) Menú diario y pedidos diarios (modo multi-restaurante)
DO $$
BEGIN
  -- Políticas para menus_diarios, sólo si existe la tabla
  IF to_regclass('public.menus_diarios') IS NOT NULL THEN
    -- Eliminar todas las políticas existentes
    DROP POLICY IF EXISTS "menus_public_select" ON public.menus_diarios;
    DROP POLICY IF EXISTS "menus_public_insert" ON public.menus_diarios;
    DROP POLICY IF EXISTS "menus_public_update" ON public.menus_diarios;
    DROP POLICY IF EXISTS "menus_select_same_rest" ON public.menus_diarios;
    DROP POLICY IF EXISTS "menus_write_admin" ON public.menus_diarios;

    CREATE POLICY "menus_select_same_rest" ON public.menus_diarios
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.perfiles_usuarios pu
          WHERE pu.id = auth.uid() AND pu.restaurante_id = menus_diarios.restaurante_id
        )
      );

    CREATE POLICY "menus_write_admin" ON public.menus_diarios
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM public.perfiles_usuarios pu
          WHERE pu.id = auth.uid() AND pu.restaurante_id = menus_diarios.restaurante_id AND pu.rol IN ('admin')
        )
      ) WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.perfiles_usuarios pu
          WHERE pu.id = auth.uid() AND pu.restaurante_id = menus_diarios.restaurante_id AND pu.rol IN ('admin')
        )
      );
  END IF;

  -- Políticas para pedidos_diarios, sólo si existe la tabla
  IF to_regclass('public.pedidos_diarios') IS NOT NULL THEN
    -- Eliminar todas las políticas existentes
    DROP POLICY IF EXISTS "pd_public_select" ON public.pedidos_diarios;
    DROP POLICY IF EXISTS "pd_public_insert" ON public.pedidos_diarios;
    DROP POLICY IF EXISTS "pd_public_update" ON public.pedidos_diarios;
    DROP POLICY IF EXISTS "pd_public_delete" ON public.pedidos_diarios;
    DROP POLICY IF EXISTS "pd_select_same_rest" ON public.pedidos_diarios;
    DROP POLICY IF EXISTS "pd_write_same_rest" ON public.pedidos_diarios;

    CREATE POLICY "pd_select_same_rest" ON public.pedidos_diarios
      FOR SELECT USING (
        EXISTS (
          SELECT 1 FROM public.perfiles_usuarios pu
          WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos_diarios.restaurante_id
        )
      );

    CREATE POLICY "pd_write_same_rest" ON public.pedidos_diarios
      FOR ALL USING (
        EXISTS (
          SELECT 1 FROM public.perfiles_usuarios pu
          WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos_diarios.restaurante_id
        )
      ) WITH CHECK (
        EXISTS (
          SELECT 1 FROM public.perfiles_usuarios pu
          WHERE pu.id = auth.uid() AND pu.restaurante_id = pedidos_diarios.restaurante_id
        )
      );
  END IF;
END $$;

-- 10) Índices útiles
CREATE INDEX IF NOT EXISTS idx_pedidos_rest ON public.pedidos(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_platos_rest ON public.platos(restaurante_id);
CREATE INDEX IF NOT EXISTS idx_items_pedido_pedido ON public.items_pedido(pedido_id);

-- Nota: el service_role ignora RLS (para tareas de administración/backoffice)