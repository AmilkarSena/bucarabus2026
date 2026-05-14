# =============================================
# Script de Despliegue - Funciones de Cancelación v3.0 (LOCAL)
# =============================================
# Descripción: Despliega fun_cancel_trip_v3 y fun_cancel_trips_batch_v3
# Uso: .\deploy-cancel-functions-local.ps1
# =============================================

$ErrorActionPreference = "Stop"

# Configuración de conexión local
$DB_HOST = "localhost"
$DB_PORT = "5432"
$DB_NAME = "bucarabus_local"
$DB_USER = "postgres"
$DB_PASSWORD = "postgres"  # Cambiar si es diferente

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🚌 BucaraBus - Funciones de Cancelación v3.0       ║" -ForegroundColor Cyan
Write-Host "║   📍 Ambiente: LOCAL                                  ║" -ForegroundColor Cyan
Write-Host "║   🗄️  Base de Datos: $DB_NAME                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Obtener el directorio donde está el script
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Archivo a desplegar
$FILE = "fun_cancel_trip_v3.sql"
$file_path = Join-Path $SCRIPT_DIR $FILE

Write-Host "📋 Función a desplegar:" -ForegroundColor Yellow
Write-Host "   ✓ $FILE (incluye fun_cancel_trip + fun_cancel_trips_batch)" -ForegroundColor Gray
Write-Host ""

if (-Not (Test-Path $file_path)) {
    Write-Host "❌ ERROR: Archivo no encontrado: $FILE" -ForegroundColor Red
    exit 1
}

Write-Host "📤 Desplegando: $FILE..." -ForegroundColor Cyan

try {
    # Buscar psql en rutas comunes
    $psqlPaths = @(
        "C:\Program Files\PostgreSQL\16\bin\psql.exe",
        "C:\Program Files\PostgreSQL\15\bin\psql.exe",
        "C:\Program Files\PostgreSQL\14\bin\psql.exe",
        "C:\Program Files\PostgreSQL\13\bin\psql.exe"
    )
    
    $psqlExe = $null
    foreach ($path in $psqlPaths) {
        if (Test-Path $path) {
            $psqlExe = $path
            break
        }
    }
    
    if ($null -eq $psqlExe) {
        # Intentar usar psql del PATH
        $psqlExe = "psql"
    }
    
    # Ejecutar archivo SQL con psql
    $env:PGPASSWORD = $DB_PASSWORD
    
    & $psqlExe -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $file_path 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ $FILE desplegado exitosamente" -ForegroundColor Green
        $success_count = 1
    } else {
        Write-Host "   ❌ Error al desplegar $FILE (código: $LASTEXITCODE)" -ForegroundColor Red
        $success_count = 0
    }
}
catch {
    Write-Host "   ❌ Excepción al desplegar $FILE : $_" -ForegroundColor Red
    $success_count = 0
}

Write-Host ""

# Resumen final
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   📊 RESUMEN DEL DESPLIEGUE                           ║" -ForegroundColor Cyan
Write-Host "╠════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

if ($success_count -eq 1) {
    Write-Host "║   ✅ Exitoso: 2 funciones desplegadas                 ║" -ForegroundColor Green
    Write-Host "║      • fun_cancel_trip v3.0                          ║" -ForegroundColor Green
    Write-Host "║      • fun_cancel_trips_batch v3.0                   ║" -ForegroundColor Green
} else {
    Write-Host "║   ❌ Fallido: Revise los errores arriba              ║" -ForegroundColor Red
}

Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($success_count -eq 1) {
    Write-Host ""
    Write-Host "🎉 ¡Despliegue completado exitosamente!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📝 NOTAS IMPORTANTES:" -ForegroundColor Yellow
    Write-Host "   • Las funciones usan SMALLINT (1-5) para estados" -ForegroundColor White
    Write-Host "   • is_active = FALSE libera horarios para reutilización" -ForegroundColor White
    Write-Host "   • Cancelar viajes activos requiere force_cancel=TRUE + motivo" -ForegroundColor White
    Write-Host "   • Eventos registrados en tab_trip_events" -ForegroundColor White
    Write-Host ""
    Write-Host "🧪 PRUEBA:" -ForegroundColor Cyan
    Write-Host "   -- Cancelar viaje pending/assigned:" -ForegroundColor Gray
    Write-Host "   SELECT * FROM fun_cancel_trip(123, 42, NULL, FALSE);" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   -- Cancelar viaje activo (emergencia):" -ForegroundColor Gray
    Write-Host "   SELECT * FROM fun_cancel_trip(456, 42, 'Bus varado', TRUE);" -ForegroundColor Gray
    Write-Host ""
    exit 0
} else {
    Write-Host ""
    Write-Host "⚠️  Despliegue completado con errores" -ForegroundColor Yellow
    Write-Host "💡 Revisa los mensajes de error arriba" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔍 SOLUCIÓN ALTERNATIVA:" -ForegroundColor Cyan
    Write-Host "   Abre DBeaver/pgAdmin y ejecuta manualmente:" -ForegroundColor White
    Write-Host "   $file_path" -ForegroundColor Gray
    Write-Host ""
    exit 1
}
