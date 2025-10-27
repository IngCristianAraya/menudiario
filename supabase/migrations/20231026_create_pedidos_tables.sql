-- Crear tipo de enumeración para estados
create type estado_pedido as enum ('pendiente', 'en_preparacion', 'listo', 'entregado', 'cancelado');

-- Tabla de pedidos
create table if not exists pedidos (
  id uuid primary key default uuid_generate_v4(),
  codigo_pedido varchar(10) unique not null,
  cliente_id uuid references auth.users(id) on delete set null,
  estado estado_pedido not null default 'pendiente',
  tipo_entrega text not null check (tipo_entrega in ('mesa', 'domicilio', 'recojo')),
  detalles_entrega jsonb,
  total numeric(10,2) not null,
  fecha_pedido timestamp with time zone default now(),
  restaurante_id uuid references restaurantes(id) not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

-- Tabla de ítems del pedido
create table if not exists items_pedido (
  id uuid primary key default uuid_generate_v4(),
  pedido_id uuid references pedidos(id) on delete cascade,
  plato_id uuid references platos(id),
  cantidad integer not null check (cantidad > 0),
  precio_unitario numeric(10,2) not null,
  notas text,
  estado estado_pedido not null default 'pendiente',
  created_at timestamp with time zone default now()
);

-- Función para actualizar automáticamente el campo updated_at
create or replace function update_updated_at_column()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Trigger para actualizar automáticamente updated_at
create trigger update_pedidos_updated_at
before update on pedidos
for each row
execute function update_updated_at_column();

-- Políticas de seguridad RLS
alter table pedidos enable row level security;
alter table items_pedido enable row level security;

-- Crear políticas de seguridad para pedidos
create policy "Los usuarios pueden ver sus propios pedidos"
  on pedidos for select
  using (auth.uid() = cliente_id);

create policy "El personal del restaurante puede ver los pedidos de su restaurante"
  on pedidos for select
  using (
    exists (
      select 1 from perfiles_usuarios
      where perfiles_usuarios.id = auth.uid()
      and perfiles_usuarios.restaurante_id = pedidos.restaurante_id
    )
  );

-- Índices para mejorar el rendimiento
create index idx_pedidos_estado on pedidos(estado);
create index idx_pedidos_restaurante on pedidos(restaurante_id);
create index idx_items_pedido_pedido_id on items_pedido(pedido_id);
