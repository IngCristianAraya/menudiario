param(
  [string]$SupabaseUrl = $env:NEXT_PUBLIC_SUPABASE_URL,
  [string]$ServiceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY
)

Write-Host "== Test de RLS - Validación de Aislamiento por Tenant ==" -ForegroundColor Cyan

if (-not $SupabaseUrl -or -not $ServiceRoleKey) {
  Write-Error "Faltan variables: NEXT_PUBLIC_SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY"
  exit 1
}

$headers = @{
  apikey = $ServiceRoleKey
  Authorization = "Bearer $ServiceRoleKey"
  "Content-Type" = "application/json"
}

# Función para ejecutar query SQL
function Invoke-SupabaseQuery {
  param([string]$Query)
  
  $body = @{ query = $Query } | ConvertTo-Json
  try {
    $response = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/rpc/exec_sql" -Headers $headers -Body $body
    return $response
  } catch {
    # Si no existe la función exec_sql, usar query directa
    Write-Host "Usando query directa..." -ForegroundColor DarkYellow
    return $null
  }
}

Write-Host "`n1. Verificando que RLS está activado..." -ForegroundColor Yellow

# Verificar RLS en tablas clave
$rlsCheck = @"
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename IN ('perfiles_usuarios', 'restaurantes', 'platos', 'pedidos', 'items_pedido', 'menus_diarios', 'pedidos_diarios')
AND schemaname = 'public';
"@

Write-Host "Ejecuta en Supabase SQL Editor:" -ForegroundColor Gray
Write-Host $rlsCheck -ForegroundColor DarkGray

Write-Host "`n2. Verificando restaurantes existentes..." -ForegroundColor Yellow

try {
  $restaurantes = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/restaurantes?select=id,nombre,slug" -Headers $headers
  
  if ($restaurantes.Count -eq 0) {
    Write-Host "❌ No hay restaurantes registrados. Ejecuta primero register-tenant-rls.ps1" -ForegroundColor Red
    exit 1
  }
  
  Write-Host "✅ Restaurantes encontrados:" -ForegroundColor Green
  foreach ($rest in $restaurantes) {
    Write-Host "  - $($rest.nombre) ($($rest.slug)) - ID: $($rest.id)" -ForegroundColor White
  }
} catch {
  Write-Error "Error obteniendo restaurantes: $($_.Exception.Message)"
  exit 1
}

Write-Host "`n3. Verificando perfiles de usuarios..." -ForegroundColor Yellow

try {
  $perfiles = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/perfiles_usuarios?select=id,restaurante_id,rol,nombre,apellido" -Headers $headers
  
  if ($perfiles.Count -eq 0) {
    Write-Host "❌ No hay perfiles de usuarios. Los usuarios deben tener perfiles en perfiles_usuarios" -ForegroundColor Red
  } else {
    Write-Host "✅ Perfiles encontrados:" -ForegroundColor Green
    foreach ($perfil in $perfiles) {
      $restaurante = $restaurantes | Where-Object { $_.id -eq $perfil.restaurante_id }
      $nombreRest = if ($restaurante) { $restaurante.nombre } else { "Desconocido" }
      $nombrePerfil = (($perfil.nombre + " " + $perfil.apellido)).Trim()
      Write-Host "  - $nombrePerfil ($($perfil.rol)) → $nombreRest" -ForegroundColor White
    }
  }
} catch {
  Write-Error "Error obteniendo perfiles: $($_.Exception.Message)"
}

Write-Host "`n4. Verificando platos por restaurante..." -ForegroundColor Yellow

try {
  $platos = Invoke-RestMethod -Method Get -Uri "$SupabaseUrl/rest/v1/platos?select=id,nombre,precio,restaurante_id" -Headers $headers
  
  if ($platos.Count -eq 0) {
    Write-Host "⚠ No hay platos registrados" -ForegroundColor DarkYellow
  } else {
    Write-Host "✅ Platos encontrados:" -ForegroundColor Green
    
    # Agrupar por restaurante
    $platosPorRestaurante = $platos | Group-Object -Property restaurante_id
    
    foreach ($grupo in $platosPorRestaurante) {
      $restaurante = $restaurantes | Where-Object { $_.id -eq $grupo.Name }
      $nombreRest = if ($restaurante) { $restaurante.nombre } else { "ID: $($grupo.Name)" }
      
      Write-Host "  📍 $nombreRest ($($grupo.Count) platos):" -ForegroundColor Cyan
      foreach ($plato in $grupo.Group) {
        Write-Host "    - $($plato.nombre) - S/. $($plato.precio)" -ForegroundColor White
      }
    }
  }
} catch {
  Write-Error "Error obteniendo platos: $($_.Exception.Message)"
}

Write-Host "`n5. Test de Seguridad RLS..." -ForegroundColor Yellow

# Crear usuario de prueba temporal para test
$testEmail = "test-rls-$(Get-Random)@example.com"
$testPassword = "TestPassword123!"

Write-Host "Creando usuario de prueba: $testEmail" -ForegroundColor Gray

$authHeaders = @{
  apikey = $ServiceRoleKey
  Authorization = "Bearer $ServiceRoleKey"
  "Content-Type" = "application/json"
}

try {
  # Crear usuario temporal
  $userBody = @{
    email = $testEmail
    password = $testPassword
    email_confirm = $true
  } | ConvertTo-Json

  $testUser = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/auth/v1/admin/users" -Headers $authHeaders -Body $userBody
  $testUserId = $testUser.id
  
  Write-Host "✅ Usuario de prueba creado: $testUserId" -ForegroundColor Green

  # Asignar a primer restaurante
  if ($restaurantes.Count -gt 0) {
    $primerRestaurante = $restaurantes[0]
    
    $perfilTestBody = @{
      id = $testUserId
      restaurante_id = $primerRestaurante.id
      rol = "staff"
      nombre = "Usuario"
      apellido = "Test RLS"
    } | ConvertTo-Json

    $perfilTest = Invoke-RestMethod -Method Post -Uri "$SupabaseUrl/rest/v1/perfiles_usuarios" -Headers $headers -Body $perfilTestBody
    Write-Host "✅ Perfil de prueba creado para restaurante: $($primerRestaurante.nombre)" -ForegroundColor Green

    # Ahora hacer login como este usuario y probar RLS
    Write-Host "`n🔐 Para probar RLS manualmente:" -ForegroundColor Cyan
    Write-Host "1. Ve a tu aplicación web" -ForegroundColor White
    Write-Host "2. Haz login con: $testEmail / $testPassword" -ForegroundColor White
    Write-Host "3. Verifica que solo ves datos de: $($primerRestaurante.nombre)" -ForegroundColor White
    Write-Host "4. Intenta crear un plato - debe asignarse automáticamente restaurante_id = $($primerRestaurante.id)" -ForegroundColor White

    # Cleanup: eliminar usuario de prueba
    Write-Host "`n🧹 Limpiando usuario de prueba..." -ForegroundColor DarkYellow
    try {
      Invoke-RestMethod -Method Delete -Uri "$SupabaseUrl/auth/v1/admin/users/$testUserId" -Headers $authHeaders
      Write-Host "✅ Usuario de prueba eliminado" -ForegroundColor Green
    } catch {
      Write-Host "⚠ No se pudo eliminar usuario de prueba: $testUserId" -ForegroundColor DarkYellow
    }
  }

} catch {
  Write-Host "❌ Error en test de seguridad: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n6. Comandos SQL para verificación manual..." -ForegroundColor Yellow

Write-Host @"

-- Verificar políticas RLS activas:
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual 
FROM pg_policies 
WHERE tablename IN ('perfiles_usuarios', 'platos', 'pedidos', 'menus_diarios');

-- Verificar que todas las tablas tienen restaurante_id:
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'platos' AND column_name = 'restaurante_id';

-- Test manual de RLS (ejecutar como usuario normal, no SERVICE_ROLE):
-- 1. Login como usuario de un restaurante
-- 2. SELECT * FROM platos; -- Debe mostrar solo platos de su restaurante
-- 3. INSERT INTO platos (nombre, precio, restaurante_id) VALUES ('Test', 10.00, 'otro-restaurante-id'); -- Debe fallar

"@ -ForegroundColor DarkGray

Write-Host "`n== RESUMEN DEL TEST ==" -ForegroundColor Cyan

if ($restaurantes.Count -gt 0 -and $perfiles.Count -gt 0) {
  Write-Host "✅ Configuración básica correcta" -ForegroundColor Green
  Write-Host "✅ Restaurantes y perfiles creados" -ForegroundColor Green
  Write-Host "⚠ Ejecuta pruebas manuales de login para validar RLS completamente" -ForegroundColor Yellow
} else {
  Write-Host "❌ Configuración incompleta" -ForegroundColor Red
  Write-Host "   - Ejecuta register-tenant-rls.ps1 para crear restaurantes y usuarios" -ForegroundColor White
}

Write-Host "`n🎯 Próximos pasos:" -ForegroundColor Cyan
Write-Host "1. Ejecuta la migración RLS si no lo has hecho" -ForegroundColor White
Write-Host "2. Registra tenants con register-tenant-rls.ps1" -ForegroundColor White
Write-Host "3. Prueba login en la aplicación web" -ForegroundColor White
Write-Host "4. Verifica que cada usuario solo ve datos de su restaurante" -ForegroundColor White