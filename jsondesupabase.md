[
  {
    "schema_json": {
      "views": [
        {
          "name": "tenants_view",
          "definition": " SELECT id,\n    nombre,\n    slug AS subdominio,\n    configuracion,\n    COALESCE(activo, true) AS activo\n   FROM restaurantes r;"
        }
      ],
      "tables": [
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "text",
              "column_name": "nombre",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "descripcion",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "restaurante_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "integer",
              "column_name": "orden",
              "is_nullable": "YES",
              "column_default": "0"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "categorias_platos_pkey",
              "definition": "CREATE UNIQUE INDEX categorias_platos_pkey ON public.categorias_platos USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'admin'::text))))",
              "policyname": "Admin: Acceso total a categorías",
              "with_check": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'admin'::text))))"
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'personal'::text) AND (perfiles_usuarios.restaurante_id = categorias_platos.restaurante_id))))",
              "policyname": "Empleados: Ver categorías de su restaurante",
              "with_check": null
            }
          ],
          "table_name": "categorias_platos",
          "constraints": [
            {
              "name": "categorias_platos_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "fk_categorias_restaurante",
              "type": "f",
              "definition": "FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id) ON DELETE CASCADE"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "uuid",
              "column_name": "tenant_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "name",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "description",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "image_url",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "integer",
              "column_name": "display_order",
              "is_nullable": "YES",
              "column_default": "0"
            },
            {
              "data_type": "boolean",
              "column_name": "is_active",
              "is_nullable": "YES",
              "column_default": "true"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "deleted_at",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "categories_pkey",
              "definition": "CREATE UNIQUE INDEX categories_pkey ON public.categories USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users\n  WHERE ((tenant_users.user_id = auth.uid()) AND (tenant_users.tenant_id = categories.tenant_id) AND (tenant_users.role = ANY (ARRAY['admin'::user_role, 'super_admin'::user_role])))))",
              "policyname": "Admins can manage categories in their tenants",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users\n  WHERE ((tenant_users.user_id = auth.uid()) AND (tenant_users.tenant_id = categories.tenant_id))))",
              "policyname": "Users can view categories from their tenants",
              "with_check": null
            }
          ],
          "table_name": "categories",
          "constraints": [
            {
              "name": "categories_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "categories_tenant_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "uuid",
              "column_name": "pedido_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "plato_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "integer",
              "column_name": "cantidad",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "precio_unitario",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "notas",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "USER-DEFINED",
              "column_name": "estado",
              "is_nullable": "NO",
              "column_default": "'pendiente'::estado_pedido"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "idx_items_pedido_pedido",
              "definition": "CREATE INDEX idx_items_pedido_pedido ON public.items_pedido USING btree (pedido_id)"
            },
            {
              "name": "idx_items_pedido_pedido_id",
              "definition": "CREATE INDEX idx_items_pedido_pedido_id ON public.items_pedido USING btree (pedido_id)"
            },
            {
              "name": "items_pedido_pkey",
              "definition": "CREATE UNIQUE INDEX items_pedido_pkey ON public.items_pedido USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM (pedidos p\n     JOIN perfiles_usuarios pu ON ((pu.restaurante_id = p.restaurante_id)))\n  WHERE ((p.id = items_pedido.pedido_id) AND (pu.id = auth.uid()))))",
              "policyname": "items_select_same_rest",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM pedidos p\n  WHERE ((p.id = items_pedido.pedido_id) AND ((p.restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n           FROM perfiles_usuarios\n          WHERE (perfiles_usuarios.id = auth.uid()))) OR (p.cliente_id = auth.uid()) OR (auth.uid() IS NULL)))))",
              "policyname": "items_select_same_restaurant",
              "with_check": null
            },
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM (pedidos p\n     JOIN perfiles_usuarios pu ON ((pu.restaurante_id = p.restaurante_id)))\n  WHERE ((p.id = items_pedido.pedido_id) AND (pu.id = auth.uid()))))",
              "policyname": "items_write_same_rest",
              "with_check": "(EXISTS ( SELECT 1\n   FROM (pedidos p\n     JOIN perfiles_usuarios pu ON ((pu.restaurante_id = p.restaurante_id)))\n  WHERE ((p.id = items_pedido.pedido_id) AND (pu.id = auth.uid()))))"
            },
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM pedidos p\n  WHERE ((p.id = items_pedido.pedido_id) AND ((p.restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n           FROM perfiles_usuarios\n          WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL)))))",
              "policyname": "items_write_same_restaurant",
              "with_check": null
            }
          ],
          "table_name": "items_pedido",
          "constraints": [
            {
              "name": "items_pedido_cantidad_check",
              "type": "c",
              "definition": "CHECK ((cantidad > 0))"
            },
            {
              "name": "items_pedido_pedido_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (pedido_id) REFERENCES pedidos(id) ON DELETE CASCADE"
            },
            {
              "name": "items_pedido_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "items_pedido_plato_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (plato_id) REFERENCES platos(id)"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "gen_random_uuid()"
            },
            {
              "data_type": "text",
              "column_name": "nombre",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "precio",
              "is_nullable": "NO",
              "column_default": "0"
            },
            {
              "data_type": "text",
              "column_name": "emoji",
              "is_nullable": "YES",
              "column_default": "'🍽️'::text"
            },
            {
              "data_type": "boolean",
              "column_name": "activo",
              "is_nullable": "YES",
              "column_default": "true"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "uuid",
              "column_name": "restaurante_id",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "idx_menus_activo",
              "definition": "CREATE INDEX idx_menus_activo ON public.menus_diarios USING btree (activo)"
            },
            {
              "name": "idx_menus_diarios_restaurante",
              "definition": "CREATE INDEX idx_menus_diarios_restaurante ON public.menus_diarios USING btree (restaurante_id)"
            },
            {
              "name": "menus_diarios_pkey",
              "definition": "CREATE UNIQUE INDEX menus_diarios_pkey ON public.menus_diarios USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "INSERT",
              "qual": null,
              "policyname": "Acceso público a menú - INSERT",
              "with_check": "true"
            },
            {
              "cmd": "SELECT",
              "qual": "true",
              "policyname": "Acceso público a menú - SELECT",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "true",
              "policyname": "Acceso público a menú - UPDATE",
              "with_check": "true"
            },
            {
              "cmd": "SELECT",
              "qual": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL))",
              "policyname": "menus_select_same_rest",
              "with_check": null
            },
            {
              "cmd": "ALL",
              "qual": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = ANY (ARRAY['admin'::text, 'super_admin'::text]))))) OR (auth.uid() IS NULL))",
              "policyname": "menus_write_admin",
              "with_check": null
            }
          ],
          "table_name": "menus_diarios",
          "constraints": [
            {
              "name": "menus_diarios_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            }
          ],
          "rls_enabled": true,
          "row_estimate": 8
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "uuid",
              "column_name": "order_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "product_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "product_name",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "product_price",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "integer",
              "column_name": "quantity",
              "is_nullable": "NO",
              "column_default": "1"
            },
            {
              "data_type": "text",
              "column_name": "notes",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "order_items_pkey",
              "definition": "CREATE UNIQUE INDEX order_items_pkey ON public.order_items USING btree (id)"
            }
          ],
          "policies": [],
          "table_name": "order_items",
          "constraints": [
            {
              "name": "order_items_order_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE"
            },
            {
              "name": "order_items_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "order_items_product_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE SET NULL"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "uuid",
              "column_name": "tenant_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "user_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "status",
              "is_nullable": "NO",
              "column_default": "'pending'::text"
            },
            {
              "data_type": "text",
              "column_name": "customer_name",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "customer_phone",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "customer_email",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "jsonb",
              "column_name": "delivery_address",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "subtotal",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "tax_amount",
              "is_nullable": "NO",
              "column_default": "0"
            },
            {
              "data_type": "numeric",
              "column_name": "delivery_fee",
              "is_nullable": "NO",
              "column_default": "0"
            },
            {
              "data_type": "numeric",
              "column_name": "total_amount",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "notes",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "completed_at",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "idx_orders_tenant_id",
              "definition": "CREATE INDEX idx_orders_tenant_id ON public.orders USING btree (tenant_id)"
            },
            {
              "name": "idx_orders_user_id",
              "definition": "CREATE INDEX idx_orders_user_id ON public.orders USING btree (user_id)"
            },
            {
              "name": "orders_pkey",
              "definition": "CREATE UNIQUE INDEX orders_pkey ON public.orders USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "SELECT",
              "qual": "(user_id = auth.uid())",
              "policyname": "Customers can view their own orders",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users\n  WHERE ((tenant_users.user_id = auth.uid()) AND (tenant_users.tenant_id = orders.tenant_id) AND (tenant_users.role = ANY (ARRAY['staff'::user_role, 'admin'::user_role, 'super_admin'::user_role])))))",
              "policyname": "Staff can view all orders in their tenant",
              "with_check": null
            }
          ],
          "table_name": "orders",
          "constraints": [
            {
              "name": "orders_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "orders_tenant_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE"
            },
            {
              "name": "orders_user_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE SET NULL"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "character varying",
              "column_name": "codigo_pedido",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "cliente_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "USER-DEFINED",
              "column_name": "estado",
              "is_nullable": "NO",
              "column_default": "'pendiente'::estado_pedido"
            },
            {
              "data_type": "text",
              "column_name": "tipo_entrega",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "jsonb",
              "column_name": "detalles_entrega",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "total",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "fecha_pedido",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "uuid",
              "column_name": "restaurante_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "idx_pedidos_estado",
              "definition": "CREATE INDEX idx_pedidos_estado ON public.pedidos USING btree (estado)"
            },
            {
              "name": "idx_pedidos_rest",
              "definition": "CREATE INDEX idx_pedidos_rest ON public.pedidos USING btree (restaurante_id)"
            },
            {
              "name": "idx_pedidos_restaurante",
              "definition": "CREATE INDEX idx_pedidos_restaurante ON public.pedidos USING btree (restaurante_id)"
            },
            {
              "name": "pedidos_codigo_pedido_key",
              "definition": "CREATE UNIQUE INDEX pedidos_codigo_pedido_key ON public.pedidos USING btree (codigo_pedido)"
            },
            {
              "name": "pedidos_pkey",
              "definition": "CREATE UNIQUE INDEX pedidos_pkey ON public.pedidos USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.restaurante_id = pedidos.restaurante_id))))",
              "policyname": "El personal del restaurante puede ver los pedidos de su restaur",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(auth.uid() = cliente_id)",
              "policyname": "Los usuarios pueden ver sus propios pedidos",
              "with_check": null
            },
            {
              "cmd": "INSERT",
              "qual": null,
              "policyname": "pedidos_insert_same_rest",
              "with_check": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = pedidos.restaurante_id))))"
            },
            {
              "cmd": "INSERT",
              "qual": null,
              "policyname": "pedidos_insert_same_restaurant",
              "with_check": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL))"
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = pedidos.restaurante_id))))",
              "policyname": "pedidos_select_same_rest",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (cliente_id = auth.uid()) OR (auth.uid() IS NULL))",
              "policyname": "pedidos_select_same_restaurant",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = pedidos.restaurante_id))))",
              "policyname": "pedidos_update_same_rest",
              "with_check": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = pedidos.restaurante_id))))"
            },
            {
              "cmd": "UPDATE",
              "qual": "(restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid())))",
              "policyname": "pedidos_update_same_restaurant",
              "with_check": null
            }
          ],
          "table_name": "pedidos",
          "constraints": [
            {
              "name": "pedidos_cliente_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (cliente_id) REFERENCES auth.users(id) ON DELETE SET NULL"
            },
            {
              "name": "pedidos_codigo_pedido_key",
              "type": "u",
              "definition": "UNIQUE (codigo_pedido)"
            },
            {
              "name": "pedidos_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "pedidos_restaurante_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id)"
            },
            {
              "name": "pedidos_tipo_entrega_check",
              "type": "c",
              "definition": "CHECK ((tipo_entrega = ANY (ARRAY['mesa'::text, 'domicilio'::text, 'recojo'::text])))"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "gen_random_uuid()"
            },
            {
              "data_type": "text",
              "column_name": "tipo",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "jsonb",
              "column_name": "items",
              "is_nullable": "NO",
              "column_default": "'[]'::jsonb"
            },
            {
              "data_type": "numeric",
              "column_name": "total",
              "is_nullable": "NO",
              "column_default": "0"
            },
            {
              "data_type": "date",
              "column_name": "fecha",
              "is_nullable": "YES",
              "column_default": "CURRENT_DATE"
            },
            {
              "data_type": "time without time zone",
              "column_name": "hora",
              "is_nullable": "YES",
              "column_default": "CURRENT_TIME"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "uuid",
              "column_name": "restaurante_id",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "idx_pedidos_diarios_restaurante",
              "definition": "CREATE INDEX idx_pedidos_diarios_restaurante ON public.pedidos_diarios USING btree (restaurante_id)"
            },
            {
              "name": "idx_pedidos_fecha",
              "definition": "CREATE INDEX idx_pedidos_fecha ON public.pedidos_diarios USING btree (fecha)"
            },
            {
              "name": "idx_pedidos_tipo",
              "definition": "CREATE INDEX idx_pedidos_tipo ON public.pedidos_diarios USING btree (tipo)"
            },
            {
              "name": "pedidos_diarios_pkey",
              "definition": "CREATE UNIQUE INDEX pedidos_diarios_pkey ON public.pedidos_diarios USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "DELETE",
              "qual": "true",
              "policyname": "Acceso público a pedidos - DELETE",
              "with_check": null
            },
            {
              "cmd": "INSERT",
              "qual": null,
              "policyname": "Acceso público a pedidos - INSERT",
              "with_check": "true"
            },
            {
              "cmd": "SELECT",
              "qual": "true",
              "policyname": "Acceso público a pedidos - SELECT",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "true",
              "policyname": "Acceso público a pedidos - UPDATE",
              "with_check": "true"
            },
            {
              "cmd": "SELECT",
              "qual": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL))",
              "policyname": "pd_select_same_rest",
              "with_check": null
            },
            {
              "cmd": "ALL",
              "qual": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL))",
              "policyname": "pd_write_same_rest",
              "with_check": null
            }
          ],
          "table_name": "pedidos_diarios",
          "constraints": [
            {
              "name": "pedidos_diarios_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "pedidos_diarios_tipo_check",
              "type": "c",
              "definition": "CHECK ((tipo = ANY (ARRAY['local'::text, 'delivery'::text])))"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "nombre",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "apellido",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "telefono",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "rol",
              "is_nullable": "NO",
              "column_default": "'cliente'::text"
            },
            {
              "data_type": "uuid",
              "column_name": "restaurante_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "perfiles_usuarios_pkey",
              "definition": "CREATE UNIQUE INDEX perfiles_usuarios_pkey ON public.perfiles_usuarios USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "INSERT",
              "qual": null,
              "policyname": "perfiles_insert_own_restaurant",
              "with_check": "((restaurante_id = ( SELECT perfiles_usuarios_1.restaurante_id\n   FROM perfiles_usuarios perfiles_usuarios_1\n  WHERE (perfiles_usuarios_1.id = auth.uid()))) OR (auth.uid() IS NULL))"
            },
            {
              "cmd": "SELECT",
              "qual": "(restaurante_id = ( SELECT perfiles_usuarios_1.restaurante_id\n   FROM perfiles_usuarios perfiles_usuarios_1\n  WHERE (perfiles_usuarios_1.id = auth.uid())))",
              "policyname": "perfiles_select_own_restaurant",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "(restaurante_id = ( SELECT perfiles_usuarios_1.restaurante_id\n   FROM perfiles_usuarios perfiles_usuarios_1\n  WHERE (perfiles_usuarios_1.id = auth.uid())))",
              "policyname": "perfiles_update_own_restaurant",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(auth.uid() = id)",
              "policyname": "pu_select_own",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "(auth.uid() = id)",
              "policyname": "pu_update_own",
              "with_check": "(auth.uid() = id)"
            }
          ],
          "table_name": "perfiles_usuarios",
          "constraints": [
            {
              "name": "perfiles_usuarios_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE"
            },
            {
              "name": "perfiles_usuarios_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "perfiles_usuarios_restaurante_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id) ON DELETE SET NULL"
            },
            {
              "name": "perfiles_usuarios_rol_check",
              "type": "c",
              "definition": "CHECK ((rol = ANY (ARRAY['admin'::text, 'personal'::text, 'cliente'::text])))"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "text",
              "column_name": "nombre",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "descripcion",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "precio",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "imagen_url",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "categoria_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "restaurante_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "boolean",
              "column_name": "activo",
              "is_nullable": "YES",
              "column_default": "true"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "idx_platos_rest",
              "definition": "CREATE INDEX idx_platos_rest ON public.platos USING btree (restaurante_id)"
            },
            {
              "name": "platos_pkey",
              "definition": "CREATE UNIQUE INDEX platos_pkey ON public.platos USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'admin'::text))))",
              "policyname": "Admin: Acceso total a platos",
              "with_check": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'admin'::text))))"
            },
            {
              "cmd": "SELECT",
              "qual": "((activo = true) AND (EXISTS ( SELECT 1\n   FROM categorias_platos\n  WHERE (categorias_platos.id = platos.categoria_id))))",
              "policyname": "Clientes: Ver platos activos",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'personal'::text) AND (perfiles_usuarios.restaurante_id = platos.restaurante_id))))",
              "policyname": "Empleados: Ver platos de su restaurante",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = platos.restaurante_id))))",
              "policyname": "platos_select_same_rest",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "((restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL))",
              "policyname": "platos_select_same_restaurant",
              "with_check": null
            },
            {
              "cmd": "ALL",
              "qual": "(restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = ANY (ARRAY['admin'::text, 'super_admin'::text])))))",
              "policyname": "platos_write_admin",
              "with_check": "(restaurante_id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = ANY (ARRAY['admin'::text, 'super_admin'::text])))))"
            }
          ],
          "table_name": "platos",
          "constraints": [
            {
              "name": "fk_platos_categoria",
              "type": "f",
              "definition": "FOREIGN KEY (categoria_id) REFERENCES categorias_platos(id) ON DELETE SET NULL"
            },
            {
              "name": "fk_platos_restaurante",
              "type": "f",
              "definition": "FOREIGN KEY (restaurante_id) REFERENCES restaurantes(id) ON DELETE CASCADE"
            },
            {
              "name": "platos_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "uuid",
              "column_name": "tenant_id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "category_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "name",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "description",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "numeric",
              "column_name": "price",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "image_url",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "boolean",
              "column_name": "is_available",
              "is_nullable": "YES",
              "column_default": "true"
            },
            {
              "data_type": "boolean",
              "column_name": "is_featured",
              "is_nullable": "YES",
              "column_default": "false"
            },
            {
              "data_type": "integer",
              "column_name": "display_order",
              "is_nullable": "YES",
              "column_default": "0"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "deleted_at",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "idx_products_tenant_id",
              "definition": "CREATE INDEX idx_products_tenant_id ON public.products USING btree (tenant_id)"
            },
            {
              "name": "products_pkey",
              "definition": "CREATE UNIQUE INDEX products_pkey ON public.products USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users\n  WHERE ((tenant_users.user_id = auth.uid()) AND (tenant_users.tenant_id = products.tenant_id) AND (tenant_users.role = ANY (ARRAY['admin'::user_role, 'super_admin'::user_role])))))",
              "policyname": "Admins can manage products in their tenants",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users\n  WHERE ((tenant_users.user_id = auth.uid()) AND (tenant_users.tenant_id = products.tenant_id))))",
              "policyname": "Users can view products from their tenants",
              "with_check": null
            }
          ],
          "table_name": "products",
          "constraints": [
            {
              "name": "products_category_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL"
            },
            {
              "name": "products_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "products_tenant_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "first_name",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "last_name",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "avatar_url",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "profiles_pkey",
              "definition": "CREATE UNIQUE INDEX profiles_pkey ON public.profiles USING btree (id)"
            }
          ],
          "policies": [
            {
              "cmd": "UPDATE",
              "qual": "(auth.uid() = id)",
              "policyname": "Users can update their own profile",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(auth.uid() = id)",
              "policyname": "Users can view their own profile",
              "with_check": null
            }
          ],
          "table_name": "profiles",
          "constraints": [
            {
              "name": "profiles_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE"
            },
            {
              "name": "profiles_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "text",
              "column_name": "nombre",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "direccion",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "telefono",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "email",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "logo_url",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "jsonb",
              "column_name": "horario",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "jsonb",
              "column_name": "configuracion",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "text",
              "column_name": "slug",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "boolean",
              "column_name": "activo",
              "is_nullable": "YES",
              "column_default": "true"
            },
            {
              "data_type": "uuid",
              "column_name": "tenant_id",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "idx_restaurantes_tenant",
              "definition": "CREATE INDEX idx_restaurantes_tenant ON public.restaurantes USING btree (tenant_id)"
            },
            {
              "name": "restaurantes_pkey",
              "definition": "CREATE UNIQUE INDEX restaurantes_pkey ON public.restaurantes USING btree (id)"
            },
            {
              "name": "restaurantes_slug_key",
              "definition": "CREATE UNIQUE INDEX restaurantes_slug_key ON public.restaurantes USING btree (slug)"
            }
          ],
          "policies": [
            {
              "cmd": "ALL",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'admin'::text))))",
              "policyname": "Admin: Acceso total a restaurantes",
              "with_check": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios\n  WHERE ((perfiles_usuarios.id = auth.uid()) AND (perfiles_usuarios.rol = 'admin'::text))))"
            },
            {
              "cmd": "SELECT",
              "qual": "(id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid())))",
              "policyname": "Empleados: Ver su restaurante",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = restaurantes.id))))",
              "policyname": "rest_select_own",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = restaurantes.id) AND (pu.rol = 'admin'::text))))",
              "policyname": "rest_update_admin",
              "with_check": "(EXISTS ( SELECT 1\n   FROM perfiles_usuarios pu\n  WHERE ((pu.id = auth.uid()) AND (pu.restaurante_id = restaurantes.id) AND (pu.rol = 'admin'::text))))"
            },
            {
              "cmd": "INSERT",
              "qual": null,
              "policyname": "restaurantes_insert_public",
              "with_check": "true"
            },
            {
              "cmd": "SELECT",
              "qual": "((id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid()))) OR (auth.uid() IS NULL))",
              "policyname": "restaurantes_select_own",
              "with_check": null
            },
            {
              "cmd": "UPDATE",
              "qual": "(id = ( SELECT perfiles_usuarios.restaurante_id\n   FROM perfiles_usuarios\n  WHERE (perfiles_usuarios.id = auth.uid())))",
              "policyname": "restaurantes_update_own",
              "with_check": null
            }
          ],
          "table_name": "restaurantes",
          "constraints": [
            {
              "name": "restaurantes_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "restaurantes_slug_key",
              "type": "u",
              "definition": "UNIQUE (slug)"
            },
            {
              "name": "restaurantes_tenant_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE"
            }
          ],
          "rls_enabled": true,
          "row_estimate": 3
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "uuid",
              "column_name": "user_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "uuid",
              "column_name": "tenant_id",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "USER-DEFINED",
              "column_name": "role",
              "is_nullable": "NO",
              "column_default": "'customer'::user_role"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            }
          ],
          "indexes": [
            {
              "name": "idx_tenant_users_tenant_id",
              "definition": "CREATE INDEX idx_tenant_users_tenant_id ON public.tenant_users USING btree (tenant_id)"
            },
            {
              "name": "idx_tenant_users_user_id",
              "definition": "CREATE INDEX idx_tenant_users_user_id ON public.tenant_users USING btree (user_id)"
            },
            {
              "name": "tenant_users_pkey",
              "definition": "CREATE UNIQUE INDEX tenant_users_pkey ON public.tenant_users USING btree (id)"
            },
            {
              "name": "tenant_users_user_id_tenant_id_key",
              "definition": "CREATE UNIQUE INDEX tenant_users_user_id_tenant_id_key ON public.tenant_users USING btree (user_id, tenant_id)"
            }
          ],
          "policies": [
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users tu\n  WHERE ((tu.user_id = auth.uid()) AND (tu.tenant_id = tenant_users.tenant_id) AND (tu.role = ANY (ARRAY['admin'::user_role, 'super_admin'::user_role])))))",
              "policyname": "Admins can view tenant members",
              "with_check": null
            },
            {
              "cmd": "SELECT",
              "qual": "(user_id = auth.uid())",
              "policyname": "Users can view their tenant memberships",
              "with_check": null
            }
          ],
          "table_name": "tenant_users",
          "constraints": [
            {
              "name": "tenant_users_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "tenant_users_tenant_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE"
            },
            {
              "name": "tenant_users_user_id_fkey",
              "type": "f",
              "definition": "FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE"
            },
            {
              "name": "tenant_users_user_id_tenant_id_key",
              "type": "u",
              "definition": "UNIQUE (user_id, tenant_id)"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        },
        {
          "columns": [
            {
              "data_type": "uuid",
              "column_name": "id",
              "is_nullable": "NO",
              "column_default": "uuid_generate_v4()"
            },
            {
              "data_type": "text",
              "column_name": "name",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "slug",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "logo_url",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "contact_email",
              "is_nullable": "NO",
              "column_default": null
            },
            {
              "data_type": "text",
              "column_name": "contact_phone",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "jsonb",
              "column_name": "address",
              "is_nullable": "YES",
              "column_default": null
            },
            {
              "data_type": "boolean",
              "column_name": "is_active",
              "is_nullable": "YES",
              "column_default": "true"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "created_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "updated_at",
              "is_nullable": "YES",
              "column_default": "now()"
            },
            {
              "data_type": "timestamp with time zone",
              "column_name": "deleted_at",
              "is_nullable": "YES",
              "column_default": null
            }
          ],
          "indexes": [
            {
              "name": "tenants_pkey",
              "definition": "CREATE UNIQUE INDEX tenants_pkey ON public.tenants USING btree (id)"
            },
            {
              "name": "tenants_slug_key",
              "definition": "CREATE UNIQUE INDEX tenants_slug_key ON public.tenants USING btree (slug)"
            }
          ],
          "policies": [
            {
              "cmd": "SELECT",
              "qual": "(EXISTS ( SELECT 1\n   FROM tenant_users\n  WHERE ((tenant_users.user_id = auth.uid()) AND (tenant_users.role = 'super_admin'::user_role))))",
              "policyname": "Super admins can view all tenants",
              "with_check": null
            }
          ],
          "table_name": "tenants",
          "constraints": [
            {
              "name": "tenants_pkey",
              "type": "p",
              "definition": "PRIMARY KEY (id)"
            },
            {
              "name": "tenants_slug_key",
              "type": "u",
              "definition": "UNIQUE (slug)"
            }
          ],
          "rls_enabled": true,
          "row_estimate": -1
        }
      ],
      "samples": {
        "tenants": [
          {
            "id": "3bdf61e0-6a4f-41ce-a30b-2003e925c83e",
            "name": "La sazón criolla",
            "slug": "lasazoncriollamenu",
            "is_active": true,
            "subdomain": null,
            "contact_email": "admin@lasazoncriolla.com"
          }
        ],
        "restaurantes": [
          {
            "id": "fec3f3e2-b1cc-4c2a-a4fd-cad53bde175f",
            "slug": "lasazoncriollamenu",
            "nombre": "La sazón criolla",
            "tenant_id": "3bdf61e0-6a4f-41ce-a30b-2003e925c83e",
            "created_at": "2025-10-28T07:47:27.90797+00:00"
          },
          {
            "id": "95cb1e9c-7cde-4247-a9c6-20c012aa3e59",
            "slug": null,
            "nombre": "Restaurante Principal",
            "tenant_id": null,
            "created_at": "2025-10-26T23:47:09.714198+00:00"
          },
          {
            "id": "00000000-0000-0000-0000-000000000001",
            "slug": null,
            "nombre": "Mi Restaurante",
            "tenant_id": null,
            "created_at": "2025-10-26T21:09:41.217766+00:00"
          }
        ]
      },
      "functions": [
        {
          "name": "generate_codigo_pedido",
          "schema": "public",
          "definition": "CREATE OR REPLACE FUNCTION public.generate_codigo_pedido()\n RETURNS text\n LANGUAGE plpgsql\nAS $function$\r\nDECLARE\r\n    codigo TEXT;\r\n    existe BOOLEAN;\r\nBEGIN\r\n    LOOP\r\n        codigo := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');\r\n        SELECT EXISTS(SELECT 1 FROM pedidos WHERE codigo_pedido = codigo) INTO existe;\r\n        EXIT WHEN NOT existe;\r\n    END LOOP;\r\n    RETURN codigo;\r\nEND;\r\n$function$\n"
        },
        {
          "name": "get_auth_user_id_by_email",
          "schema": "public",
          "definition": "CREATE OR REPLACE FUNCTION public.get_auth_user_id_by_email(p_email text)\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\nAS $function$\r\nDECLARE\r\n    claims JSONB := current_setting('request.jwt.claims', true)::jsonb;\r\n    result UUID;\r\nBEGIN\r\n    IF claims->>'role' IS DISTINCT FROM 'service_role' THEN\r\n        RAISE EXCEPTION 'Acceso restringido: solo Service Role';\r\n    END IF;\r\n\r\n    SELECT u.id INTO result\r\n    FROM auth.users u\r\n    WHERE u.email = p_email\r\n    LIMIT 1;\r\n\r\n    RETURN result;\r\nEND;\r\n$function$\n"
        },
        {
          "name": "get_current_tenant_id",
          "schema": "public",
          "definition": "CREATE OR REPLACE FUNCTION public.get_current_tenant_id()\n RETURNS uuid\n LANGUAGE plpgsql\n SECURITY DEFINER\nAS $function$\r\nDECLARE\r\n    tenant_id UUID;\r\nBEGIN\r\n    SELECT tu.tenant_id INTO tenant_id\r\n    FROM public.tenant_users tu\r\n    WHERE tu.user_id = auth.uid()\r\n    LIMIT 1;\r\n    \r\n    RETURN tenant_id;\r\nEND;\r\n$function$\n"
        },
        {
          "name": "is_tenant_admin",
          "schema": "public",
          "definition": "CREATE OR REPLACE FUNCTION public.is_tenant_admin(user_id_param uuid, tenant_id_param uuid)\n RETURNS boolean\n LANGUAGE plpgsql\n SECURITY DEFINER\nAS $function$\r\nBEGIN\r\n    RETURN EXISTS (\r\n        SELECT 1 \r\n        FROM public.tenant_users \r\n        WHERE user_id = user_id_param \r\n        AND tenant_id = tenant_id_param \r\n        AND role IN ('admin', 'super_admin')\r\n    );\r\nEND;\r\n$function$\n"
        },
        {
          "name": "set_codigo_pedido",
          "schema": "public",
          "definition": "CREATE OR REPLACE FUNCTION public.set_codigo_pedido()\n RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\r\nBEGIN\r\n    IF NEW.codigo_pedido IS NULL OR NEW.codigo_pedido = '' THEN\r\n        NEW.codigo_pedido := generate_codigo_pedido();\r\n    END IF;\r\n    RETURN NEW;\r\nEND;\r\n$function$\n"
        },
        {
          "name": "update_updated_at_column",
          "schema": "public",
          "definition": "CREATE OR REPLACE FUNCTION public.update_updated_at_column()\n RETURNS trigger\n LANGUAGE plpgsql\nAS $function$\r\nBEGIN\r\n    NEW.updated_at = NOW();\r\n    RETURN NEW;\r\nEND;\r\n$function$\n"
        }
      ],
      "generated_at": "2025-10-28T20:41:13.618281+00:00"
    }
  }
]