#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Migración completa para RLS - Ejecuta todas las migraciones necesarias en orden
.DESCRIPTION
    Este script ejecuta las migraciones base y luego la migración RLS en el orden correcto
.PARAMETER Force
    Fuerza la ejecución incluso si algunas tablas ya existen
#>

param(
    [switch]$Force
)

# Verificar variables de entorno
if (-not $env:NEXT_PUBLIC_SUPABASE_URL -or -not $env:SUPABASE_SERVICE_ROLE_KEY) {
    Write-Error "Faltan variables de entorno: NEXT_PUBLIC_SUPABASE_URL y/o SUPABASE_SERVICE_ROLE_KEY"
    exit 1
}

$headers = @{
    'apikey' = $env:SUPABASE_SERVICE_ROLE_KEY
    'Authorization' = "Bearer $env:SUPABASE_SERVICE_ROLE_KEY"
    'Content-Type' = 'application/json'
}

Write-Host "=== MIGRACIÓN COMPLETA PARA RLS ===" -ForegroundColor Cyan
Write-Host "URL: $env:NEXT_PUBLIC_SUPABASE_URL" -ForegroundColor Gray

# Función para ejecutar SQL
function Invoke-SupabaseSQL {
    param([string]$SqlContent, [string]$Description)
    
    Write-Host "Ejecutando: $Description..." -ForegroundColor Yellow
    
    try {
        $body = @{ query = $SqlContent } | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri "$env:NEXT_PUBLIC_SUPABASE_URL/rest/v1/rpc/query" -Method Post -Headers $headers -Body $body
        Write-Host "✅ $Description completado" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ Error en $Description`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Función para verificar si una tabla existe
function Test-TableExists {
    param([string]$TableName)
    
    try {
        $response = Invoke-RestMethod -Uri "$env:NEXT_PUBLIC_SUPABASE_URL/rest/v1/$TableName?select=*&limit=1" -Method Get -Headers $headers
        return $true
    }
    catch {
        return $false
    }
}

Write-Host "`n1. Verificando estado actual..." -ForegroundColor Cyan

$tables = @('restaurantes', 'perfiles_usuarios', 'platos', 'pedidos', 'items_pedido')
$existingTables = @()

foreach ($table in $tables) {
    if (Test-TableExists $table) {
        $existingTables += $table
        Write-Host "✅ Tabla '$table' existe" -ForegroundColor Green
    } else {
        Write-Host "❌ Tabla '$table' NO existe" -ForegroundColor Red
    }
}

if ($existingTables.Count -eq $tables.Count -and -not $Force) {
    Write-Host "`n⚠️ Todas las tablas ya existen. Use -Force para recrear." -ForegroundColor Yellow
    Write-Host "Ejecutando solo migración RLS..." -ForegroundColor Yellow
} else {
    Write-Host "`n2. Creando tablas base..." -ForegroundColor Cyan
    
    # SQL para crear las tablas principales con los nombres correctos
    $baseSql = @"
-- Habilitar extensiones
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Crear tipos
CREATE TYPE IF NOT EXISTS user_role AS ENUM ('super_admin', 'admin', 'staff', 'customer');
CREATE TYPE IF NOT EXISTS estado_pedido AS ENUM ('pendiente', 'en_preparacion', 'listo', 'entregado', 'cancelado');

-- Tabla restaurantes (ya existe, pero asegurar estructura)
CREATE TABLE IF NOT EXISTS public.restaurantes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nombre TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    logo_url TEXT,
    email_contacto TEXT NOT NULL,
    telefono_contacto TEXT,
    direccion JSONB,
    activo BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla perfiles_usuarios (extensión de auth.users)
CREATE TABLE IF NOT EXISTS public.perfiles_usuarios (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    restaurante_id UUID REFERENCES public.restaurantes ON DELETE CASCADE,
    nombre TEXT,
    apellido TEXT,
    avatar_url TEXT,
    rol user_role NOT NULL DEFAULT 'customer',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla platos
CREATE TABLE IF NOT EXISTS public.platos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10, 2) NOT NULL,
    imagen_url TEXT,
    disponible BOOLEAN DEFAULT true,
    destacado BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla pedidos
CREATE TABLE IF NOT EXISTS public.pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    restaurante_id UUID NOT NULL REFERENCES public.restaurantes ON DELETE CASCADE,
    cliente_id UUID REFERENCES auth.users ON DELETE SET NULL,
    codigo_pedido VARCHAR(10) UNIQUE NOT NULL,
    estado estado_pedido NOT NULL DEFAULT 'pendiente',
    tipo_entrega TEXT NOT NULL CHECK (tipo_entrega IN ('mesa', 'domicilio', 'recojo')),
    detalles_entrega JSONB,
    total NUMERIC(10,2) NOT NULL,
    fecha_pedido TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla items_pedido
CREATE TABLE IF NOT EXISTS public.items_pedido (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID REFERENCES public.pedidos(id) ON DELETE CASCADE,
    plato_id UUID REFERENCES public.platos(id),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2) NOT NULL,
    notas TEXT,
    estado estado_pedido NOT NULL DEFAULT 'pendiente',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Función para generar códigos de pedido únicos
CREATE OR REPLACE FUNCTION generate_codigo_pedido()
RETURNS TEXT AS `$`$
DECLARE
    codigo TEXT;
    existe BOOLEAN;
BEGIN
    LOOP
        codigo := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        SELECT EXISTS(SELECT 1 FROM pedidos WHERE codigo_pedido = codigo) INTO existe;
        EXIT WHEN NOT existe;
    END LOOP;
    RETURN codigo;
END;
`$`$ LANGUAGE plpgsql;

-- Trigger para generar código automáticamente
CREATE OR REPLACE FUNCTION set_codigo_pedido()
RETURNS TRIGGER AS `$`$
BEGIN
    IF NEW.codigo_pedido IS NULL OR NEW.codigo_pedido = '' THEN
        NEW.codigo_pedido := generate_codigo_pedido();
    END IF;
    RETURN NEW;
END;
`$`$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_codigo_pedido ON pedidos;
CREATE TRIGGER trigger_set_codigo_pedido
    BEFORE INSERT ON pedidos
    FOR EACH ROW
    EXECUTE FUNCTION set_codigo_pedido();
"@

    if (-not (Invoke-SupabaseSQL $baseSql "Creación de tablas base")) {
        Write-Error "Error creando tablas base"
        exit 1
    }
}

Write-Host "`n3. Aplicando migración RLS..." -ForegroundColor Cyan

# Leer y ejecutar la migración RLS
$rlsMigrationPath = "supabase\migrations\20251028_rls_single_project_multitenant.sql"
if (Test-Path $rlsMigrationPath) {
    $rlsSql = Get-Content $rlsMigrationPath -Raw
    if (-not (Invoke-SupabaseSQL $rlsSql "Migración RLS")) {
        Write-Error "Error aplicando migración RLS"
        exit 1
    }
} else {
    Write-Error "No se encontró la migración RLS: $rlsMigrationPath"
    exit 1
}

Write-Host "`n4. Verificación final..." -ForegroundColor Cyan

foreach ($table in $tables) {
    if (Test-TableExists $table) {
        Write-Host "✅ Tabla '$table' verificada" -ForegroundColor Green
    } else {
        Write-Host "❌ Tabla '$table' falló verificación" -ForegroundColor Red
    }
}

Write-Host "`n🎉 Migración completa finalizada!" -ForegroundColor Green
Write-Host "Ahora puedes registrar tenants con: .\scripts\register-tenant-rls.ps1" -ForegroundColor Cyan