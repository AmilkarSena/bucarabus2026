#!/usr/bin/env pwsh
# =============================================
# Instalación BucaraBUS - Servidor Remoto
# =============================================
# Servidor: 10.5.213.111
# Base de datos: db_bucarabus
# Usuario: dlastre
# =============================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║       🚍 BucaraBUS - Instalación Servidor Remoto        ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# =============================================
# Configuración del servidor remoto
# =============================================
$DbHost = "10.5.213.111"
$DbPort = 5432
$DbName = "db_bucarabus"
$DbUser = "dlastre"
$DbPassword = "Remoto1050"

Write-Host "📋 Configuración del servidor:" -ForegroundColor Yellow
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
# Verificar conectividad al servidor
# =============================================
Write-Host ""
Write-Host "🔍 Verificando conectividad al servidor..." -ForegroundColor Yellow

try {
    $testConnection = Test-NetConnection -ComputerName $DbHost -Port $DbPort -WarningAction SilentlyContinue
    
    if ($testConnection.TcpTestSucceeded) {
        Write-Host "   ✅ Conexión TCP exitosa a ${DbHost}:${DbPort}" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  ADVERTENCIA: No se pudo conectar por TCP a ${DbHost}:${DbPort}" -ForegroundColor Yellow
        Write-Host "   Intentaré continuar de todas formas..." -ForegroundColor Gray
    }
} catch {
    Write-Host "   ⚠️  No se pudo verificar conectividad (continuando...)" -ForegroundColor Yellow
}

# =============================================
# Instrucciones antes de ejecutar
# =============================================
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                    IMPORTANTE                            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Este script ejecutará en el servidor remoto:" -ForegroundColor Yellow
Write-Host "  1. Creación de todas las tablas" -ForegroundColor White
Write-Host "  2. Instalación de 16+ funciones almacenadas" -ForegroundColor White
Write-Host "  3. Creación de índices y triggers" -ForegroundColor White
Write-Host "  4. Datos iniciales (usuario sistema, roles)" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Si las tablas YA EXISTEN, se SOBRESCRIBIRÁN" -ForegroundColor Red
Write-Host ""

$confirm = Read-Host "¿Continuar con la instalación en $DbHost ? (s/n)"

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
Write-Host "🚀 Iniciando instalación en servidor remoto..." -ForegroundColor Yellow
Write-Host "   Esto puede tomar 1-2 minutos..." -ForegroundColor Gray
Write-Host ""

# Cambiar al directorio del script para que los \i funcionen
Push-Location $scriptDir

try {
    # Configurar contraseña en variable de entorno
    $env:PGPASSWORD = $DbPassword
    
    # Ejecutar psql con los parámetros del servidor remoto
    & psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -f $deployFile
    
    $exitCode = $LASTEXITCODE
    
    # Limpiar contraseña de la variable de entorno
    $env:PGPASSWORD = $null
    
    Pop-Location
    
    if ($exitCode -eq 0) {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
        Write-Host "║                 ✅ INSTALACIÓN EXITOSA                   ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
        Write-Host ""
        Write-Host "🎉 Base de datos instalada correctamente en $DbHost" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 Próximos pasos:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "   1. Verificar que las funciones se crearon:" -ForegroundColor White
        Write-Host "      " -NoNewline
        Write-Host "`$env:PGPASSWORD='$DbPassword'; psql -h $DbHost -U $DbUser -d $DbName -c ""\df fun_*""; `$env:PGPASSWORD=`$null" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   2. Ver datos iniciales:" -ForegroundColor White
        Write-Host "      " -NoNewline
        Write-Host "`$env:PGPASSWORD='$DbPassword'; psql -h $DbHost -U $DbUser -d $DbName -c ""SELECT * FROM tab_users;""; `$env:PGPASSWORD=`$null" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   3. Configurar el backend (api/.env):" -ForegroundColor White
        Write-Host "" -ForegroundColor Gray
        Write-Host "      DB_HOST=$DbHost" -ForegroundColor Cyan
        Write-Host "      DB_PORT=$DbPort" -ForegroundColor Cyan
        Write-Host "      DB_NAME=$DbName" -ForegroundColor Cyan
        Write-Host "      DB_USER=$DbUser" -ForegroundColor Cyan
        Write-Host "      DB_PASSWORD=$DbPassword" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   4. Iniciar el backend:" -ForegroundColor White
        Write-Host "      cd api && npm install && npm run dev" -ForegroundColor Gray
        Write-Host ""
        Write-Host "   5. Configurar el frontend (.env):" -ForegroundColor White
        Write-Host "      VITE_API_URL=http://localhost:3001/api" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "   6. Iniciar el frontend:" -ForegroundColor White
        Write-Host "      npm install && npm run dev" -ForegroundColor Gray
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
        Write-Host "  2. Base de datos no existe en el servidor" -ForegroundColor White
        Write-Host "  3. Usuario no tiene permisos suficientes" -ForegroundColor White
        Write-Host "  4. Firewall bloqueando conexión al puerto $DbPort" -ForegroundColor White
        Write-Host "  5. PostgreSQL no acepta conexiones remotas (pg_hba.conf)" -ForegroundColor White
        Write-Host ""
        Write-Host "Verifica los errores arriba y vuelve a intentar." -ForegroundColor Yellow
        Write-Host ""
        
        # Limpiar contraseña aunque haya error
        $env:PGPASSWORD = $null
        
        exit $exitCode
    }
} catch {
    Pop-Location
    $env:PGPASSWORD = $null
    
    Write-Host ""
    Write-Host "❌ ERROR INESPERADO: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Stack Trace:" -ForegroundColor Gray
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "Instalación completada. Puedes cerrar esta ventana." -ForegroundColor Cyan
Write-Host ""
