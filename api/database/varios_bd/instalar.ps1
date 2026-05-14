#!/usr/bin/env pwsh
# =============================================
# Script Rápido de Instalación BucaraBUS
# =============================================
# Versión: 1.0
# Descripción: Instala la base de datos completa en un solo paso
# =============================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║       🚍 BucaraBUS - Instalación Rápida v1.0            ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# =============================================
# Configuración por defecto
# =============================================
$DbHost = "localhost"
$DbPort = 5432
$DbName = "bucarabus_db"
$DbUser = "bucarabus_user"

Write-Host "📋 Configuración:" -ForegroundColor Yellow
Write-Host "   Host:     $DbHost" -ForegroundColor White
Write-Host "   Puerto:   $DbPort" -ForegroundColor White
Write-Host "   Database: $DbName" -ForegroundColor White
Write-Host "   Usuario:  $DbUser" -ForegroundColor White
Write-Host ""

# =============================================
# Verificar que psql existe
# =============================================
Write-Host "🔍 Verificando PostgreSQL..." -ForegroundColor Yellow

try {
    $psqlVersion = & psql --version 2>$null
    Write-Host "   ✅ PostgreSQL encontrado: $psqlVersion" -ForegroundColor Green
} catch {
    Write-Host "   ❌ ERROR: psql no encontrado en el PATH" -ForegroundColor Red
    Write-Host "" 
    Write-Host "   Soluciones:" -ForegroundColor Yellow
    Write-Host "   1. Instalar PostgreSQL desde: https://www.postgresql.org/download/" -ForegroundColor White
    Write-Host "   2. Agregar PostgreSQL al PATH del sistema" -ForegroundColor White
    Write-Host "      Ejemplo: C:\Program Files\PostgreSQL\14\bin" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# =============================================
# Verificar que deploy-all.sql existe
# =============================================
Write-Host ""
Write-Host "🔍 Verificando archivos..." -ForegroundColor Yellow

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deployFile = Join-Path $scriptDir "deploy-all.sql"

if (-not (Test-Path $deployFile)) {
    Write-Host "   ❌ ERROR: No se encontró deploy-all.sql" -ForegroundColor Red
    Write-Host "   Ubicación esperada: $deployFile" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

Write-Host "   ✅ deploy-all.sql encontrado" -ForegroundColor Green

# =============================================
# Instrucciones antes de ejecutar
# =============================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    IMPORTANTE                            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este script ejecutará:" -ForegroundColor Yellow
Write-Host "  1. Creación de todas las tablas" -ForegroundColor White
Write-Host "  2. Instalación de 16+ funciones almacenadas" -ForegroundColor White
Write-Host "  3. Creación de índices y triggers" -ForegroundColor White
Write-Host "  4. Datos iniciales (usuario sistema, roles)" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Si la base de datos YA EXISTE, se SOBRESCRIBIRÁ" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "¿Continuar? (s/n)"

if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host ""
    Write-Host "❌ Instalación cancelada por el usuario" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# =============================================
# Ejecutar deployment
# =============================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    EJECUTANDO                            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "🚀 Iniciando instalación..." -ForegroundColor Yellow
Write-Host ""
Write-Host "   Ingresa la contraseña del usuario: $DbUser" -ForegroundColor Yellow
Write-Host "   (Contraseña por defecto: bucarabus2025)" -ForegroundColor Gray
Write-Host ""

# Cambiar al directorio del script para que los \i funcionen
Push-Location $scriptDir

try {
    # Ejecutar psql
    $env:PGPASSWORD = $null  # Forzar que pida contraseña
    
    & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $deployFile
    
    $exitCode = $LASTEXITCODE
    
    Pop-Location
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                 ✅ INSTALACIÓN EXITOSA                   ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 Base de datos instalada correctamente" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 Próximos pasos:" -ForegroundColor Yellow
        Write-Host "   1. Verificar que las funciones se crearon:" -ForegroundColor White
        Write-Host "      psql -U $DbUser -d $DbName -c ""\df fun_*""" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   2. Ver datos iniciales:" -ForegroundColor White
        Write-Host "      psql -U $DbUser -d $DbName -c ""SELECT * FROM tab_users;""" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   3. Configurar el backend (API):" -ForegroundColor White
        Write-Host "      - Editar api/.env con los datos de conexión" -ForegroundColor Gray
        Write-Host "      - cd api && npm install" -ForegroundColor Gray
        Write-Host "      - npm run dev" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   4. Configurar el frontend:" -ForegroundColor White
        Write-Host "      - Editar .env con la URL del API" -ForegroundColor Gray
        Write-Host "      - npm install" -ForegroundColor Gray
        Write-Host "      - npm run dev" -ForegroundColor Gray
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║                   ❌ ERROR                               ║" -ForegroundColor Red
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        Write-Host "La instalación falló. Código de salida: $exitCode" -ForegroundColor Red
        Write-Host ""
        Write-Host "Posibles causas:" -ForegroundColor Yellow
        Write-Host "  1. Contraseña incorrecta" -ForegroundColor White
        Write-Host "  2. Base de datos no existe (crear con: CREATE DATABASE $DbName;)" -ForegroundColor White
        Write-Host "  3. Usuario no tiene permisos" -ForegroundColor White
        Write-Host "  4. PostgreSQL no está corriendo" -ForegroundColor White
        Write-Host ""
        Write-Host "Verifica los errores arriba y vuelve a intentar." -ForegroundColor Yellow
        Write-Host ""
        exit $exitCode
    }
} catch {
    Pop-Location
    Write-Host ""
    Write-Host "❌ ERROR INESPERADO: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "Instalación completada." -ForegroundColor Cyan
Write-Host ""
