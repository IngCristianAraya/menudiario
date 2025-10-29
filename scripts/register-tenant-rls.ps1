param(
  [Parameter(Mandatory = $true)][string]$Subdomain,
  [Parameter(Mandatory = $true)][string]$Name,
  [string]$AdminEmail,
  [string]$AdminPassword,
  [string]$RestauranteId
)

Write-Host "== Registro de tenant (Modo RLS - Un Solo Proyecto) ==" -ForegroundColor Cyan
Write-Host "Subdomain: $Subdomain"
Write-Host "Name: $Name"

# Cargar variables globales (un solo proyecto)
$SupabaseUrl = $env:NEXT_PUBLIC_SUPABASE_URL
$SupabaseServiceRole = $env:SUPABASE_SERVICE_ROLE_KEY
$SupabaseAnonKey = $env:NEXT_PUBLIC_SUPABASE_ANON_KEY
$RootDomain = $env:NEXT_PUBLIC_ROOT_DOMAIN

if (-not $SupabaseUrl -or -not $SupabaseServiceRole) {
  Write-Error "Faltan variables globales: NEXT_PUBLIC_SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY"
  exit 1
}

# Generar UUID para restaurante si no se proporciona
if (-not $RestauranteId) {
  $RestauranteId = [System.Guid]::NewGuid().ToString()
  Write-Host "UUID generado para restaurante: $RestauranteId" -ForegroundColor Yellow
}

# Headers para Supabase con SERVICE_ROLE
$headers = @{ 
  apikey = $SupabaseServiceRole
  Authorization = "Bearer $SupabaseServiceRole"
  "Content-Type" = "application/json"
  Prefer = "return=representation,resolution=merge-duplicates"
}

# Detectar columna identificadora en 'tenants' (slug, subdomain, subdominio)
$tenantKey = $null
try {
  $tenantProbe = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/tenants?select=id,slug,subdomain,subdominio&limit=1" -Headers $headers
  if ($tenantProbe) {
    if ($tenantProbe[0].slug -ne $null) { $tenantKey = 'slug' }
    elseif ($tenantProbe[0].subdomain -ne $null) { $tenantKey = 'subdomain' }
    elseif ($tenantProbe[0].subdominio -ne $null) { $tenantKey = 'subdominio' }
  }
} catch {}
if (-not $tenantKey) { $tenantKey = 'slug' } # por defecto

# Detectar columna email en 'restaurantes' (email_contacto vs email)
$restEmailKey = 'email_contacto'
try {
  $restProbe = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/restaurantes?select=id,email_contacto,email&limit=1" -Headers $headers
  if ($restProbe) {
    if ($restProbe[0].email_contacto -ne $null) { $restEmailKey = 'email_contacto' }
    elseif ($restProbe[0].email -ne $null) { $restEmailKey = 'email' }
  }
} catch {}

# 1) Upsert de tenant en tabla 'tenants'
Write-Host "1) Insertando/actualizando tenant en 'tenants'..." -ForegroundColor Yellow
$tenantBody = @{ 
  name = $Name
  is_active = $true
}
$tenantBody[$tenantKey] = $Subdomain
$tenantJson = $tenantBody | ConvertTo-Json

try {
  $tenantResp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/tenants" -Headers $headers -Body $tenantJson
  $tenantId = $tenantResp[0].id
  Write-Host "✓ Tenant upsert: ID=$tenantId ($tenantKey=$Subdomain)" -ForegroundColor Green
} catch {
  Write-Error "Error upsert tenant: $($_.Exception.Message)"
  exit 1
}

# 2) Registrar restaurante en tabla 'restaurantes' y vincular tenant_id
Write-Host "2) Insertando restaurante y vinculando tenant_id..." -ForegroundColor Yellow
$restBodyMap = @{ 
  id = $RestauranteId
  nombre = $Name
  slug = $Subdomain
  activo = $true
}
if ($AdminEmail) { $restBodyMap[$restEmailKey] = $AdminEmail }
if ($tenantId) { $restBodyMap['tenant_id'] = $tenantId }
$restauranteBody = $restBodyMap | ConvertTo-Json

try {
  $resp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/restaurantes" -Headers $headers -Body $restauranteBody
  Write-Host "✓ Restaurante registrado: $($resp | ConvertTo-Json -Compress)" -ForegroundColor Green
} catch {
  if ($_.Exception.Message -like "*duplicate key*") {
    Write-Host "⚠ Restaurante ya existe, actualizando vínculo tenant_id..." -ForegroundColor DarkYellow
    try {
      $updateHeaders = $headers.Clone(); $updateHeaders.Prefer = "return=representation"
      $updateBody = @{ tenant_id = $tenantId } | ConvertTo-Json
      $updateResp = Invoke-RestMethod -Method Patch -Uri "$SupabaseUrl/rest/v1/restaurantes?slug=eq.$Subdomain" -Headers $updateHeaders -Body $updateBody
      Write-Host "✓ Restaurante vinculado a tenant_id=$tenantId" -ForegroundColor Green
    } catch {
      Write-Error "Error actualizando restaurante: $($_.Exception.Message)"
      exit 1
    }
  } else {
    Write-Error "Error registrando restaurante: $($_.Exception.Message)"
    exit 1
  }
}

# 2) Crear usuario admin si se proporciona
Write-Host "2) Creando usuario admin..." -ForegroundColor Yellow
$adminUserId = $null

if ($AdminEmail -and $AdminPassword) {
  # Crear usuario en auth.users usando Admin API
  $authHeaders = @{
    apikey = $SupabaseServiceRole
    Authorization = "Bearer $SupabaseServiceRole"
    "Content-Type" = "application/json"
  }
  
  $userBody = @{
    email = $AdminEmail
    password = $AdminPassword
    email_confirm = $true
  } | ConvertTo-Json

  try {
    $userResp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/auth/v1/admin/users" -Headers $authHeaders -Body $userBody
    $adminUserId = $userResp.id
    Write-Host "✓ Usuario admin creado: $AdminEmail (ID: $adminUserId)" -ForegroundColor Green
  } catch {
    $status = $null
    if ($_.Exception -and $_.Exception.Response) { $status = $_.Exception.Response.StatusCode }
    if ($status -eq 422 -or $_.Exception.Message -like "*already registered*" -or $_.Exception.Message -like "*duplicate*") {
      Write-Host "⚠ Usuario ya existe o no puede crearse (422). Obteniendo ID..." -ForegroundColor DarkYellow

      # 1) Intento: Admin API con filtro por email
      $candidate = $null
      try {
        $encodedEmail = [System.Uri]::EscapeDataString($AdminEmail)
        $lookupUri = ('{0}/auth/v1/admin/users?email={1}' -f $SupabaseUrl, $encodedEmail)
        $lookupResp = Invoke-RestMethod -Method Get -Uri $lookupUri -Headers $authHeaders
        if ($lookupResp -is [System.Collections.IEnumerable]) {
          $candidate = ($lookupResp | Where-Object { $_.email -eq $AdminEmail } | Select-Object -First 1)
        } else {
          $candidate = $lookupResp
        }
      } catch {
        Write-Host "⚠ Error consultando Admin API: $($_.Exception.Message)" -ForegroundColor DarkYellow
      }

      if ($candidate -and $candidate.id) {
        $adminUserId = $candidate.id
        Write-Host "✓ Usuario encontrado: $AdminEmail (ID: $adminUserId)" -ForegroundColor Green
      } else {
        # 2) Fallback: RPC get_auth_user_id_by_email (solo Service Role)
        try {
          $rpcBody = @{ p_email = $AdminEmail } | ConvertTo-Json
          $rpcUri = ('{0}/rest/v1/rpc/get_auth_user_id_by_email' -f $SupabaseUrl)
          $rpcResp = Invoke-RestMethod -Method Post -Uri $rpcUri -Headers $headers -Body $rpcBody
          if ($rpcResp) {
            $adminUserId = $rpcResp
            Write-Host "✓ Usuario recuperado vía RPC: $AdminEmail (ID: $adminUserId)" -ForegroundColor Green
          } else {
            Write-Host "⚠ RPC no devolvió ID; intentando perfiles_usuarios..." -ForegroundColor DarkYellow
          }
        } catch {
          Write-Host "⚠ Error RPC get_auth_user_id_by_email: $($_.Exception.Message)" -ForegroundColor DarkYellow
        }

        # 3) Fallback adicional: buscar perfil existente si la tabla ya lo contiene
        if (-not $adminUserId) {
          try {
            $perfilQueryUri = ('{0}/rest/v1/perfiles_usuarios?select=id&rol=eq.admin&restaurante_id=eq.{1}&limit=1' -f $SupabaseUrl, $RestauranteId)
            $perfilQueryResp = Invoke-RestMethod -Method Get -Uri $perfilQueryUri -Headers $headers
            if ($perfilQueryResp -and $perfilQueryResp[0] -and $perfilQueryResp[0].id) {
              $adminUserId = $perfilQueryResp[0].id
              Write-Host "✓ ID recuperado desde perfiles_usuarios: $adminUserId" -ForegroundColor Green
            } else {
              Write-Error "No fue posible recuperar el ID de usuario admin por ninguno de los métodos"
            }
          } catch {
            Write-Error "Error en fallback perfiles_usuarios: $($_.Exception.Message)"
          }
        }
      }
    } else {
      Write-Error "Error creando usuario admin: $($_.Exception.Message)"
    }
  }
} else {
  Write-Host "⚠ Admin NO creado (falta -AdminEmail y -AdminPassword)." -ForegroundColor DarkYellow
}

# 3) Crear perfil de usuario en perfiles_usuarios
if ($adminUserId) {
  Write-Host "3) Creando perfil de usuario..." -ForegroundColor Yellow
  
  $perfilBody = @{
    id = $adminUserId
    restaurante_id = $RestauranteId
    rol = "admin"
    nombre = "Admin"
    apellido = $Name
  } | ConvertTo-Json

  try {
    $perfilResp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/perfiles_usuarios" -Headers $headers -Body $perfilBody
    Write-Host "✓ Perfil de usuario creado" -ForegroundColor Green
  } catch {
    if ($_.Exception.Message -like "*duplicate key*") {
      Write-Host "⚠ Perfil ya existe, actualizando..." -ForegroundColor DarkYellow
      
      # Actualizar perfil existente
      $updateHeaders = $headers.Clone()
      $updateHeaders.Prefer = "return=representation"
      
      try {
        $updateResp = Invoke-RestMethod -Method Patch -Uri "$SupabaseUrl/rest/v1/perfiles_usuarios?id=eq.$adminUserId" -Headers $updateHeaders -Body $perfilBody
        Write-Host "✓ Perfil actualizado" -ForegroundColor Green
      } catch {
        Write-Error "Error actualizando perfil: $($_.Exception.Message)"
      }
    } else {
      Write-Error "Error creando perfil: $($_.Exception.Message)"
    }
  }
}

# 3.1) Registrar relación tenant_users (si existe tabla)
if ($adminUserId -and $tenantId) {
  Write-Host "3.1) Creando relación tenant_users (user-tenant)..." -ForegroundColor Yellow
  try {
    $tuBody = @{ user_id = $adminUserId; tenant_id = $tenantId; role = 'admin' } | ConvertTo-Json
    $tuResp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/tenant_users" -Headers $headers -Body $tuBody
    Write-Host "✓ tenant_users registrado" -ForegroundColor Green
  } catch {
    Write-Host "⚠ No se pudo crear tenant_users: $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
}

# 4) Crear algunos platos de ejemplo (opcional)
Write-Host "4) Creando platos de ejemplo..." -ForegroundColor Yellow
$platosEjemplo = @(
  @{ nombre = "Menú Ejecutivo"; descripcion = "Plato del día con entrada, segundo y postre"; precio = 15.00 },
  @{ nombre = "Ensalada César"; descripcion = "Lechuga, pollo, crutones y aderezo césar"; precio = 12.00 },
  @{ nombre = "Lomo Saltado"; descripcion = "Lomo de res saltado con papas fritas"; precio = 25.00 }
)

foreach ($plato in $platosEjemplo) {
  $platoBodyMap = @{
    nombre = $plato.nombre
    descripcion = $plato.descripcion
    precio = $plato.precio
    restaurante_id = $RestauranteId
  }
  # detectar columna de estado (disponible vs activo)
  $platoStateKey = 'disponible'
  try {
    $platoProbe = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/platos?select=id,disponible,activo&limit=1" -Headers $headers
    if ($platoProbe -and $platoProbe[0].activo -ne $null) { $platoStateKey = 'activo' }
  } catch {}
  $platoBodyMap[$platoStateKey] = $true
  $platoBody = $platoBodyMap | ConvertTo-Json

  try {
    $platoResp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/platos" -Headers $headers -Body $platoBody
    Write-Host "✓ Plato creado: $($plato.nombre)" -ForegroundColor Green
  } catch {
    Write-Host "⚠ Error creando plato '$($plato.nombre)': $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
}

# 5) Resumen final
Write-Host "`n== RESUMEN ==" -ForegroundColor Cyan
Write-Host "Restaurante ID: $RestauranteId"
Write-Host "Subdominio: $Subdomain"
Write-Host "Nombre: $Name"
if ($adminUserId) {
  Write-Host "Admin User ID: $adminUserId"
  Write-Host "Admin Email: $AdminEmail"
}
if ($tenantId) {
  Write-Host "Tenant ID: $tenantId"
}

if ($RootDomain) {
  Write-Host "`nPrueba el login en: https://$Subdomain.$RootDomain/auth/login" -ForegroundColor Green
} else {
  Write-Host "`nConfigura NEXT_PUBLIC_ROOT_DOMAIN para obtener la URL de prueba" -ForegroundColor DarkYellow
}

Write-Host "`n✅ Registro completado exitosamente!" -ForegroundColor Green

# 6) Comandos de verificación
Write-Host "`n== COMANDOS DE VERIFICACIÓN ==" -ForegroundColor Cyan
Write-Host "Verificar restaurante creado:"
Write-Host "SELECT * FROM restaurantes WHERE id = '$RestauranteId';" -ForegroundColor Gray

if ($tenantId) {
  Write-Host "`nVerificar tenant creado:"
  Write-Host "SELECT * FROM tenants WHERE id = '$tenantId';" -ForegroundColor Gray
}

if ($adminUserId) {
  Write-Host "`nVerificar perfil de usuario:"
  Write-Host "SELECT * FROM perfiles_usuarios WHERE id = '$adminUserId';" -ForegroundColor Gray
  
  Write-Host "`nVerificar platos del restaurante:"
  Write-Host "SELECT * FROM platos WHERE restaurante_id = '$RestauranteId';" -ForegroundColor Gray
}

Write-Host "`nVerificar RLS funcionando (debe mostrar solo datos del restaurante logueado):"
Write-Host "-- Loguéate como $AdminEmail y ejecuta:"
Write-Host "SELECT * FROM platos;" -ForegroundColor Gray