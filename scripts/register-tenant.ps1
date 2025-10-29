param(
  [Parameter(Mandatory = $true)][string]$Subdomain,
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$TenantSupabaseUrl,
  [Parameter(Mandatory = $true)][string]$TenantSupabaseAnonKey,
  [Parameter(Mandatory = $true)][string]$TenantSupabaseServiceRoleKey,
  [string]$AdminEmail,
  [string]$AdminPassword
)

Write-Host "== Registro de tenant ==" -ForegroundColor Cyan
Write-Host "Subdomain: $Subdomain"
Write-Host "Name: $Name"

# Cargar variables globales
$CoreUrl = $env:NEXT_PUBLIC_SUPABASE_URL
$CoreServiceRole = $env:SUPABASE_SERVICE_ROLE_KEY
$RootDomain = $env:NEXT_PUBLIC_ROOT_DOMAIN
$VercelToken = $env:VERCEL_TOKEN
$VercelProjectId = $env:VERCEL_PROJECT_ID

if (-not $CoreUrl -or -not $CoreServiceRole) {
  Write-Error "Faltan variables globales: NEXT_PUBLIC_SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY"
  exit 1
}

# 1) Registrar en BD central (upsert)
Write-Host "1) Insertando/actualizando tenant en BD central..." -ForegroundColor Yellow
$tenantBody = @{ subdominio = $Subdomain; nombre = $Name; activo = $true } | ConvertTo-Json
$headers = @{ apikey = $CoreServiceRole; Authorization = "Bearer $CoreServiceRole"; "Content-Type" = "application/json"; Prefer = "return=representation,resolution=merge-duplicates" }
try {
  $resp = Invoke-RestMethod -Method Post -Uri "$CoreUrl/rest/v1/tenants" -Headers $headers -Body $tenantBody
  Write-Host "Tenant registrado: $($resp | ConvertTo-Json -Compress)"
} catch {
  Write-Error "Error registrando tenant en Supabase central: $($_.Exception.Message)"
  exit 1
}

# 2) Crear env vars en Vercel (opcional)
Write-Host "2) Configurando variables en Vercel..." -ForegroundColor Yellow
if ($VercelToken -and $VercelProjectId) {
  $vercelHeaders = @{ Authorization = "Bearer $VercelToken"; "Content-Type" = "application/json" }
  $vars = @(
    @{ key = "SUPABASE_URL__${Subdomain}"; value = $TenantSupabaseUrl },
    @{ key = "SUPABASE_ANON_KEY__${Subdomain}"; value = $TenantSupabaseAnonKey },
    @{ key = "SUPABASE_SERVICE_ROLE__${Subdomain}"; value = $TenantSupabaseServiceRoleKey }
  )

  foreach ($v in $vars) {
    $body = @{ key = $v.key; value = $v.value; target = @("production"); type = "encrypted" } | ConvertTo-Json
    try {
      $res = Invoke-RestMethod -Method Post -Uri "https://api.vercel.com/v10/projects/$VercelProjectId/env" -Headers $vercelHeaders -Body $body
      Write-Host "✓ Env creada: $($v.key)"
    } catch {
      Write-Error "Error creando env $($v.key) en Vercel: $($_.Exception.Message)"
    }
  }
  Write-Host "Variables creadas. Vercel debería redeployar automáticamente." -ForegroundColor Green
} else {
  Write-Host "Saltando creación en Vercel (faltan VERCEL_TOKEN o VERCEL_PROJECT_ID)." -ForegroundColor DarkYellow
}

# 3) Crear admin (opcional)
Write-Host "3) Creando usuario admin..." -ForegroundColor Yellow
if ($AdminEmail -and $AdminPassword) {
  if (-not $RootDomain) {
    Write-Error "Falta NEXT_PUBLIC_ROOT_DOMAIN para construir la URL del tenant"
  } else {
    $endpoint = "https://$Subdomain.$RootDomain/api/tenants/$Subdomain/create-admin"
    $adminHeaders = @{ "x-client-service-role" = $TenantSupabaseServiceRoleKey; "Content-Type" = "application/json" }
    $adminBody = @{ email = $AdminEmail; password = $AdminPassword } | ConvertTo-Json
    try {
      $adminResp = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $adminHeaders -Body $adminBody
      Write-Host "✓ Admin creado: $($adminResp.user.email)" -ForegroundColor Green
    } catch {
      Write-Error "Error creando admin (verifica DNS y env vars): $($_.Exception.Message)"
    }
  }
} else {
  Write-Host "Admin NO creado (falta -AdminEmail y -AdminPassword)." -ForegroundColor DarkYellow
}

Write-Host "Listo. Prueba login en: https://$Subdomain.$RootDomain/auth/login" -ForegroundColor Cyan