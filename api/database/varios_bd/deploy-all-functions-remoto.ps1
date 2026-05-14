# =============================================
# Deploy TODAS las funciones v3.0 - REMOTO
# =============================================
# Despliega fun_create_user y fun_create_driver v3.0
# al servidor PostgreSQL remoto 10.5.213.111
# =============================================

# Configuración del servidor remoto
$env:PGHOST = "10.5.213.111"
$env:PGPORT = "5432"
$env:PGDATABASE = "db_bucarabus"
$env:PGUSER = "dlastre"
$env:PGPASSWORD = "Remoto1050"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deploy Funciones v3.0 - SERVIDOR REMOTO" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Servidor: $env:PGHOST" -ForegroundColor Yellow
Write-Host "Base de datos: $env:PGDATABASE" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

$errors = 0

# ==========================================
# 1. Deploy fun_create_user v3.0
# ==========================================
Write-Host "📝 [1/2] Desplegando fun_create_user v3.0..." -ForegroundColor Cyan
$sqlFile1 = Join-Path $PSScriptRoot "fun_create_user.sql"

if (-not (Test-Path $sqlFile1)) {
    Write-Host "   ❌ ERROR: No se encuentra fun_create_user.sql" -ForegroundColor Red
    $errors++
} else {
    try {
        psql -f $sqlFile1 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ fun_create_user v3.0 desplegada" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Error al desplegar fun_create_user" -ForegroundColor Red
            $errors++
        }
    } catch {
        Write-Host "   ❌ Excepción: $_" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""

# ==========================================
# 2. Deploy fun_create_driver v3.0
# ==========================================
Write-Host "🚗 [2/2] Desplegando fun_create_driver v3.0..." -ForegroundColor Cyan
$sqlFile2 = Join-Path $PSScriptRoot "fun_create_driver.sql"

if (-not (Test-Path $sqlFile2)) {
    Write-Host "   ❌ ERROR: No se encuentra fun_create_driver.sql" -ForegroundColor Red
    $errors++
} else {
    try {
        psql -f $sqlFile2 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ fun_create_driver v3.0 desplegada" -ForegroundColor Green
        } else {
            Write-Host "   ❌ Error al desplegar fun_create_driver" -ForegroundColor Red
            $errors++
        }
    } catch {
        Write-Host "   ❌ Excepción: $_" -ForegroundColor Red
        $errors++
    }
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan

# ==========================================
# RESUMEN
# ==========================================
if ($errors -eq 0) {
    Write-Host "✅ DEPLOY COMPLETADO EXITOSAMENTE" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Funciones actualizadas a v3.0:" -ForegroundColor Yellow
    Write-Host "  • fun_create_user - ID secuencial (MAX+1)" -ForegroundColor White
    Write-Host "  • fun_create_driver - ID secuencial (MAX+1)" -ForegroundColor White
    Write-Host ""
    Write-Host "Ahora puedes:" -ForegroundColor Yellow
    Write-Host "  1. Crear usuarios desde el backend" -ForegroundColor White
    Write-Host "  2. Crear conductores desde el backend" -ForegroundColor White
    Write-Host "  3. Los IDs se generarán automáticamente de forma secuencial" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "❌ DEPLOY COMPLETADO CON ERRORES ($errors)" -ForegroundColor Red
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Revisa los mensajes de error arriba" -ForegroundColor Yellow
    exit 1
}
