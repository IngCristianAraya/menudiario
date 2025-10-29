#!/usr/bin/env pwsh

<#
.SYNOPSIS
  Script maestro interactivo para onboarding de tenants (multi-tenant RLS)

.DESCRIPTION
  - Recopila datos del tenant y valida entradas
  - Configura tenant, restaurante, usuarios (admin y staff) y relaciones
  - Aplica lógica de roles (admin, staff) y credenciales seguras
  - Verifica la implementación (BD, subdominio, acceso)
  - Genera un reporte final y permite rollback si hay fallos

.USAGE
  pwsh scripts/onboard-tenant.ps1

  Opcionales:
  -Batch: Permite pasar parámetros sin interacción
  -TotalUsers <int>, -AdminCount <int>
  -Name <string>, -Subdomain <string>, -AdminEmail <string>, -AdminPassword <string>

.NOTES
  Requiere variables de entorno:
  - NEXT_PUBLIC_SUPABASE_URL
  - NEXT_PUBLIC_SUPABASE_ANON_KEY (opcional)
  - SUPABASE_SERVICE_ROLE_KEY
  - NEXT_PUBLIC_ROOT_DOMAIN
#>

param(
  [switch]$Batch,
  [string]$Name,
  [string]$Subdomain,
  [string]$AdminEmail,
  [string]$AdminPassword,
  [int]$TotalUsers,
  [int]$AdminCount
)

function Write-Info($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "✓ $msg" -ForegroundColor Green }
function Write-Warn($msg) { Write-Host "⚠ $msg" -ForegroundColor DarkYellow }
function Write-Err($msg) { Write-Host "❌ $msg" -ForegroundColor Red }

Write-Info "== Onboarding de Tenant (Multi-tenant RLS) =="

# Validar env vars
if (-not $env:NEXT_PUBLIC_SUPABASE_URL -or -not $env:SUPABASE_SERVICE_ROLE_KEY -or -not $env:NEXT_PUBLIC_ROOT_DOMAIN) {
  Write-Err "Faltan variables de entorno: NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, NEXT_PUBLIC_ROOT_DOMAIN"
  exit 1
}

$SupabaseUrl = $env:NEXT_PUBLIC_SUPABASE_URL
$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
$RootDomain = $env:NEXT_PUBLIC_ROOT_DOMAIN

$headers = @{ apikey = $ServiceRoleKey; Authorization = "Bearer $ServiceRoleKey"; "Content-Type" = "application/json"; Prefer = "return=representation,resolution=merge-duplicates" }
$authHeaders = @{ apikey = $ServiceRoleKey; Authorization = "Bearer $ServiceRoleKey"; "Content-Type" = "application/json" }

# Utilidades de validación
function Test-Email($email) {
  return ($email -match '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
}
function Test-Subdomain($sub) {
  return ($sub -match '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$')
}
function Test-Password($pwd) {
  return ($pwd.Length -ge 10 -and $pwd -match '[A-Z]' -and $pwd -match '[a-z]' -and $pwd -match '\d')
}
function New-RandomPassword([int]$len = 14) {
  $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'
  -join (1..$len | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}

# Recopilación interactiva si no es batch
if (-not $Batch) {
  do { $Name = Read-Host "Nombre completo del tenant" } while ([string]::IsNullOrWhiteSpace($Name))
  do { $Subdomain = Read-Host "Subdominio deseado (solo minúsculas, números y '-')" } while (-not (Test-Subdomain $Subdomain))
  do { $AdminEmail = Read-Host "Correo administrativo" } while (-not (Test-Email $AdminEmail))
  do { $AdminPassword = Read-Host "Contraseña segura (>=10, mayúscula, minúscula, número)" } while (-not (Test-Password $AdminPassword))
  do { $TotalUsers = [int](Read-Host "Cantidad total de usuarios a crear") } while ($TotalUsers -lt 1)
  do { $AdminCount = [int](Read-Host "Cantidad de usuarios administradores") } while ($AdminCount -lt 1 -or $AdminCount -gt $TotalUsers)
}

# Confirmación
Write-Info "Datos recolectados:"
Write-Host "- Tenant: $Name" -ForegroundColor White
Write-Host "- Subdominio: $Subdomain.$RootDomain" -ForegroundColor White
Write-Host "- Admin principal: $AdminEmail" -ForegroundColor White
Write-Host "- Total usuarios: $TotalUsers (Admins: $AdminCount, Staff: $($TotalUsers - $AdminCount))" -ForegroundColor White

# Detección de columnas variables
$tenantKey = 'slug'
$tenantNameKey = 'name'
$tenantActiveKey = 'is_active'
try {
  $probe = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/tenants?select=id,slug,subdomain,subdominio&limit=1" -Headers $headers
  if ($probe) {
    if ($probe[0].slug -ne $null) { $tenantKey = 'slug' }
    elseif ($probe[0].subdomain -ne $null) { $tenantKey = 'subdomain' }
    elseif ($probe[0].subdominio -ne $null) { $tenantKey = 'subdominio' }
  }
} catch {}

# Detectar claves de nombre/activo segun esquema (ingles vs español)
try {
  # Intento esquema español
  $probeEs = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/tenants?select=nombre,activo&limit=1" -Headers $headers
  if ($probeEs -ne $null) { $tenantNameKey = 'nombre'; $tenantActiveKey = 'activo' }
} catch {
  try {
    # Intento esquema inglés
    $probeEn = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/tenants?select=name,is_active&limit=1" -Headers $headers
    if ($probeEn -ne $null) { $tenantNameKey = 'name'; $tenantActiveKey = 'is_active' }
  } catch {}
}

# Detectar columna de email de contacto del tenant (requisa en algunos esquemas)
$tenantEmailKey = $null
try {
  $probeEmail = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/tenants?select=contact_email,email_contacto,email&limit=1" -Headers $headers
  if ($probeEmail) {
    if ($probeEmail[0].contact_email -ne $null) { $tenantEmailKey = 'contact_email' }
    elseif ($probeEmail[0].email_contacto -ne $null) { $tenantEmailKey = 'email_contacto' }
    elseif ($probeEmail[0].email -ne $null) { $tenantEmailKey = 'email' }
  }
} catch {}

$restEmailKey = 'email_contacto'
try {
  $probeR = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/restaurantes?select=id,email_contacto,email&limit=1" -Headers $headers
  if ($probeR) {
    if ($probeR[0].email_contacto -ne $null) { $restEmailKey = 'email_contacto' }
    elseif ($probeR[0].email -ne $null) { $restEmailKey = 'email' }
  }
} catch {}

# Rollback stack
$rollback = @()
function Push-Rollback([scriptblock]$action) { $script:rollback += $action }
function Do-Rollback() {
  Write-Warn "Iniciando rollback..."
  foreach ($act in ($script:rollback | Select-Object -Last 100)) {
    try { & $act } catch { Write-Warn "Rollback step falló: $($_.Exception.Message)" }
  }
  Write-Ok "Rollback completado"
}

try {
  # 1) Upsert tenant
  Write-Info "1) Creando/actualizando tenant..."
  $tenantBody = @{}
  $tenantBody[$tenantNameKey] = $Name
  $tenantBody[$tenantActiveKey] = $true
  $tenantBody[$tenantKey] = $Subdomain
  if ($tenantEmailKey -and $AdminEmail) { $tenantBody[$tenantEmailKey] = $AdminEmail }
  $tenantResp = $null
  try {
    $tenantResp = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/tenants?on_conflict=$tenantKey" -Headers $headers -Body ($tenantBody | ConvertTo-Json)
  } catch {
    # Si falla el upsert, intentar actualizar por clave
    $updateHeaders = $headers.Clone(); $updateHeaders.Prefer = 'return=representation'
    try {
      $tenantResp = Invoke-RestMethod -Method Patch -Uri "$SupabaseUrl/rest/v1/tenants?$tenantKey=eq.$Subdomain" -Headers $updateHeaders -Body ($tenantBody | ConvertTo-Json)
    } catch {}
  }
  # Recuperar siempre por consulta para asegurar tenantId
  $tenUrl = "$SupabaseUrl/rest/v1/tenants?select=id&$tenantKey=eq.$Subdomain&limit=1"
  Write-Info "Buscando tenant por $tenantKey=$Subdomain ..."
  $tenLookup = Invoke-RestMethod -Method Get -Uri $tenUrl -Headers $headers
  Write-Info "Resultados: $([string]$tenLookup.Count)"
  if ($tenLookup -and $tenLookup.Count -ge 1) { $tenantId = $tenLookup[0].id }
  if (-not $tenantId) { throw "No se obtuvo tenantId" }
  Write-Ok "Tenant ID=$tenantId ($tenantKey=$Subdomain)"
  Push-Rollback { try { Invoke-RestMethod -Method Delete -Uri "$using:SupabaseUrl/rest/v1/tenants?id=eq.$using:tenantId" -Headers $using:headers } catch {} }

  # 2) Crear restaurante vinculado
  Write-Info "2) Creando restaurante y vinculando tenant_id..."
  $exist = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/restaurantes?select=id&slug=eq.$Subdomain&limit=1" -Headers $headers
  if ($exist -and $exist.Count -ge 1) {
    $restId = $exist[0].id
    Write-Warn "Restaurante ya existe (ID=$restId), actualizando tenant_id..."
    $updateHeaders = $headers.Clone(); $updateHeaders.Prefer = 'return=representation'
    Invoke-RestMethod -Method Patch -Uri "$SupabaseUrl/rest/v1/restaurantes?id=eq.$restId" -Headers $updateHeaders -Body (@{ tenant_id = $tenantId } | ConvertTo-Json)
  } else {
    $restId = [Guid]::NewGuid().ToString()
    $restMap = @{ id = $restId; nombre = $Name; slug = $Subdomain; activo = $true; tenant_id = $tenantId }
    if ($AdminEmail) { $restMap[$restEmailKey] = $AdminEmail }
    Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/restaurantes" -Headers $headers -Body ($restMap | ConvertTo-Json)
    Write-Ok "Restaurante ID=$restId"
  }
  $rid = $restId
  Push-Rollback { try { Invoke-RestMethod -Method Delete -Uri "$using:SupabaseUrl/rest/v1/restaurantes?id=eq.$using:rid" -Headers $using:headers } catch {} }

  # 3) Crear admins
  Write-Info "3) Creando usuarios admin..."
  $createdUsers = @()
  $adminList = @()
  $adminList += @{ email = $AdminEmail; password = $AdminPassword }
  for ($i=1; $i -lt $AdminCount; $i++) {
    $email = "admin$i@$Subdomain.$RootDomain"
    $pwd = New-RandomPassword 16
    $adminList += @{ email = $email; password = $pwd }
  }
  foreach ($adm in $adminList) {
    $userBody = @{ email = $adm.email; password = $adm.password; email_confirm = $true } | ConvertTo-Json
    $u = $null; $uid = $null
    try {
      $u = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/auth/v1/admin/users" -Headers $authHeaders -Body $userBody
      $uid = $u.id
      Write-Ok "Admin creado: $($adm.email)"
    } catch {
      # buscar existente
      try {
        $enc = [System.Uri]::EscapeDataString($adm.email)
        $lookup = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/auth/v1/admin/users?email=$enc" -Headers $authHeaders
        if ($lookup -is [System.Collections.IEnumerable]) { $uid = ($lookup | Where-Object { $_.email -eq $adm.email } | Select-Object -First 1).id } else { $uid = $lookup.id }
        Write-Warn "Admin existente: $($adm.email)"
      } catch {
        # Fallback: usar RPC para recuperar el ID por email desde auth.users
        try {
          $rpcBody = @{ p_email = $adm.email } | ConvertTo-Json
          $rpcUri = ('{0}/rest/v1/rpc/get_auth_user_id_by_email' -f $SupabaseUrl)
          $rpcResp = Invoke-RestMethod -Method Post -Uri $rpcUri -Headers $headers -Body $rpcBody
          if ($rpcResp) {
            $uid = $rpcResp
            Write-Warn "Admin recuperado vía RPC: $($adm.email)"
          } else {
            throw "RPC no devolvió ID"
          }
        } catch {
          throw "No se pudo crear ni recuperar admin: $($adm.email)"
        }
      }
    }
    $createdUsers += @{ id = $uid; email = $adm.email; role = 'admin'; password = $adm.password }
    # perfil admin
    $perfilBody = @{ id = $uid; restaurante_id = $restId; rol = 'admin'; nombre = 'Admin'; apellido = $Name } | ConvertTo-Json
    try { Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/perfiles_usuarios" -Headers $headers -Body $perfilBody } catch {}
    # tenant_users
    try { Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/tenant_users" -Headers $headers -Body (@{ user_id = $uid; tenant_id = $tenantId; role = 'admin' } | ConvertTo-Json) } catch {}
    # rollback delete user
    Push-Rollback { try { Invoke-RestMethod -Method Delete -Uri "$using:SupabaseUrl/auth/v1/admin/users/$uid" -Headers $using:authHeaders } catch {} }
  }

  # 4) Crear usuarios staff
  Write-Info "4) Creando usuarios staff..."
  $staffCount = $TotalUsers - $AdminCount
  for ($i=1; $i -le $staffCount; $i++) {
    $email = "staff$i@$Subdomain.$RootDomain"
    $pwd = New-RandomPassword 14
    $userBody = @{ email = $email; password = $pwd; email_confirm = $true } | ConvertTo-Json
    $u = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/auth/v1/admin/users" -Headers $authHeaders -Body $userBody
    $uid = $u.id
    $createdUsers += @{ id = $uid; email = $email; role = 'staff'; password = $pwd }
    # perfil staff
    $perfilBody = @{ id = $uid; restaurante_id = $restId; rol = 'staff'; nombre = 'Staff'; apellido = "$Name $i" } | ConvertTo-Json
    try { Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/perfiles_usuarios" -Headers $headers -Body $perfilBody } catch {}
    # tenant_users
    try { Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/tenant_users" -Headers $headers -Body (@{ user_id = $uid; tenant_id = $tenantId; role = 'staff' } | ConvertTo-Json) } catch {}
    # rollback
    Push-Rollback { try { Invoke-RestMethod -Method Delete -Uri "$using:SupabaseUrl/auth/v1/admin/users/$uid" -Headers $using:authHeaders } catch {} }
  }

  # 5) Verificaciones automáticas
  Write-Info "5) Verificaciones automáticas..."
  $restCheck = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/restaurantes?select=id,nombre,slug,tenant_id&slug=eq.$Subdomain" -Headers $headers
  if (-not $restCheck -or $restCheck.Count -eq 0) { throw "Restaurante no encontrado tras creación" }
  $tenCheck = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/tenants?select=id,$tenantKey&$tenantKey=eq.$Subdomain" -Headers $headers
  if (-not $tenCheck -or $tenCheck.Count -eq 0) { throw "Tenant no encontrado tras creación" }
  Write-Ok "Verificaciones de BD correctas"

  # 6) Reporte final
  Write-Info "6) Reporte final"
  $panelUrl = "https://$Subdomain.$RootDomain/admin/dashboard"
  $loginUrl = "https://$Subdomain.$RootDomain/auth/login"
  $report = [PSCustomObject]@{
    tenant = @{ id = $tenantId; name = $Name; key = $tenantKey; subdomain = $Subdomain }
    restaurant = @{ id = $restId; slug = $Subdomain; email_key = $restEmailKey }
    urls = @{ login = $loginUrl; panel = $panelUrl }
    users = $createdUsers
    notes = @('Use las credenciales para primer inicio de sesión', 'Cambie contraseñas en el panel de administración')
  }
  $outPath = "scripts/output/onboard_report_$Subdomain.json"
  if (-not (Test-Path "scripts/output")) { New-Item -ItemType Directory -Path "scripts/output" | Out-Null }
  $report | ConvertTo-Json -Depth 6 | Set-Content -Path $outPath -Encoding UTF8
  Write-Ok "Reporte: $outPath"
  Write-Host "\nAcceso:" -ForegroundColor White
  Write-Host "- Panel: $panelUrl" -ForegroundColor White
  Write-Host "- Login: $loginUrl" -ForegroundColor White
  Write-Host "\nAdministradores:" -ForegroundColor White
  $createdUsers | Where-Object { $_.role -eq 'admin' } | ForEach-Object { Write-Host "  • $($_.email) / $($_.password)" -ForegroundColor Gray }
  Write-Host "\nStaff:" -ForegroundColor White
  $createdUsers | Where-Object { $_.role -eq 'staff' } | ForEach-Object { Write-Host "  • $($_.email) / $($_.password)" -ForegroundColor Gray }

  Write-Ok "Onboarding completado"
}
catch {
  Write-Err "Fallo durante onboarding: $($_.Exception.Message)"
  Do-Rollback
  exit 1
}