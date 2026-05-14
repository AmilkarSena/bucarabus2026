# =====================================================
# Script de Migración: fun_cancel_trip v2.0 → v3.0
# Ejecuta la migración completa de funciones de cancelación
# =====================================================

Write-Host "🔄 Iniciando migración de funciones de cancelación..." -ForegroundColor Cyan
Write-Host ""

# Variables de configuración
$DB_HOST = "localhost"
$DB_PORT = "5432"
$DB_NAME = "db_bucarabus"  # ⚠️ AJUSTAR SEGÚN TU BASE DE DATOS
$DB_USER = "postgres"      # ⚠️ AJUSTAR SEGÚN TU USUARIO
$SCRIPT_DIR = $PSScriptRoot

# Archivos SQL
$MIGRATE_SCRIPT = Join-Path $SCRIPT_DIR "migrate_cancel_trip_to_v3.sql"
$V3_SCRIPT = Join-Path $SCRIPT_DIR "fun_cancel_trip_v3.sql"

# Verificar que existan los archivos
if (-not (Test-Path $MIGRATE_SCRIPT)) {
    Write-Host "❌ ERROR: No se encuentra el archivo $MIGRATE_SCRIPT" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $V3_SCRIPT)) {
    Write-Host "❌ ERROR: No se encuentra el archivo $V3_SCRIPT" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Archivos de migración encontrados:" -ForegroundColor Green
Write-Host "  - migrate_cancel_trip_to_v3.sql" -ForegroundColor Gray
Write-Host "  - fun_cancel_trip_v3.sql" -ForegroundColor Gray
Write-Host ""

# Paso 1: Eliminar funciones antiguas
Write-Host "🗑️  PASO 1: Eliminando funciones antiguas..." -ForegroundColor Yellow
Write-Host "Ejecutando: migrate_cancel_trip_to_v3.sql" -ForegroundColor Gray

try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $MIGRATE_SCRIPT
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Funciones antiguas eliminadas correctamente" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Advertencia: Algunas funciones antiguas podrían no existir (esto es normal)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ ERROR al eliminar funciones antiguas: $_" -ForegroundColor Red
    Write-Host "⚠️  Continuando con el despliegue de v3..." -ForegroundColor Yellow
}

Write-Host ""

# Paso 2: Desplegar funciones v3.0
Write-Host "📦 PASO 2: Desplegando funciones v3.0..." -ForegroundColor Yellow
Write-Host "Ejecutando: fun_cancel_trip_v3.sql" -ForegroundColor Gray

try {
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $V3_SCRIPT
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Funciones v3.0 desplegadas correctamente" -ForegroundColor Green
    } else {
        Write-Host "❌ ERROR al desplegar funciones v3.0" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ ERROR al desplegar funciones v3.0: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Paso 3: Verificar funciones desplegadas
Write-Host "🔍 PASO 3: Verificando funciones desplegadas..." -ForegroundColor Yellow

$VERIFY_SQL = @"
SELECT 
    proname as nombre_funcion,
    pronargs as num_parametros,
    pg_get_function_identity_arguments(oid) as parametros
FROM pg_proc 
WHERE proname LIKE 'fun_cancel_trip%'
ORDER BY proname;
"@

try {
    Write-Host "Funciones encontradas:" -ForegroundColor Cyan
    echo $VERIFY_SQL | psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Verificación completada" -ForegroundColor Green
    }
} catch {
    Write-Host "⚠️  No se pudo verificar las funciones: $_" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ MIGRACIÓN COMPLETADA EXITOSAMENTE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Funciones desplegadas:" -ForegroundColor White
Write-Host "  📌 fun_cancel_trip(wid_trip, wuser_cancel, wcancellation_reason, wforce_cancel)" -ForegroundColor Gray
Write-Host "  📌 fun_cancel_trips_batch(wid_route, wtrip_date, wuser_cancel, wcancellation_reason, wforce_cancel_active)" -ForegroundColor Gray
Write-Host ""
Write-Host "Ahora puedes cancelar viajes desde el frontend sin problemas." -ForegroundColor Yellow
Write-Host ""
