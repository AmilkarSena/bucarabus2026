# =============================================
# Script de Despliegue - Funciones de Viajes (LOCAL)
# =============================================
# Descripción: Despliega fun_create_trip_v3, fun_create_trips_batch_v3 y fun_update_trip_v3
# Uso: .\deploy-trip-functions-local.ps1
# =============================================

$ErrorActionPreference = "Stop"

# Configuración de conexión local
$DB_HOST = "localhost"
$DB_PORT = "5432"
$DB_NAME = "bucarabus_local"
$DB_USER = "postgres"

Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   🚌 BucaraBus - Despliegue de Funciones de Viajes  ║" -ForegroundColor Cyan
Write-Host "║   📍 Ambiente: LOCAL                                  ║" -ForegroundColor Cyan
Write-Host "║   🗄️  Base de Datos: $DB_NAME                ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Obtener el directorio donde está el script
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Archivos a desplegar en orden
$FILES = @(
    "fun_create_trip_v3.sql",
    "fun_create_trips_batch_v3.sql",
    "fun_update_trip_v3.sql",
    "fun_create_trip_event.sql"
)

Write-Host "📋 Funciones a desplegar:" -ForegroundColor Yellow
foreach ($file in $FILES) {
    Write-Host "   ✓ $file" -ForegroundColor Gray
}
Write-Host ""

# Contador de éxitos
$success_count = 0
$total_files = $FILES.Count

# Desplegar cada archivo
foreach ($file in $FILES) {
    $file_path = Join-Path $SCRIPT_DIR $file
    
    if (-Not (Test-Path $file_path)) {
        Write-Host "❌ ERROR: Archivo no encontrado: $file" -ForegroundColor Red
        continue
    }
    
    Write-Host "📤 Desplegando: $file..." -ForegroundColor Cyan
    
    try {
        # Ejecutar archivo SQL con psql
        $env:PGPASSWORD = "postgres"  # Cambiar si tu password es diferente
        
        psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f $file_path 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ $file desplegado exitosamente" -ForegroundColor Green
            $success_count++
        } else {
            Write-Host "   ❌ Error al desplegar $file (código: $LASTEXITCODE)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "   ❌ Excepción al desplegar $file : $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Resumen final
Write-Host "╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   📊 RESUMEN DEL DESPLIEGUE                           ║" -ForegroundColor Cyan
Write-Host "╠════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║   ✅ Exitosos: $success_count/$total_files                                 ║" -ForegroundColor $(if ($success_count -eq $total_files) { "Green" } else { "Yellow" })
Write-Host "║   ❌ Fallidos:  $($total_files - $success_count)/$total_files                                 ║" -ForegroundColor $(if ($success_count -eq $total_files) { "Green" } else { "Red" })
Write-Host "╚════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

if ($success_count -eq $total_files) {
    Write-Host ""
    Write-Host "🎉 ¡Despliegue completado exitosamente!" -ForegroundColor Green
    Write-Host "✨ Ahora puedes reiniciar el servidor backend" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "⚠️  Despliegue completado con errores" -ForegroundColor Yellow
    Write-Host "💡 Revisa los mensajes de error arriba" -ForegroundColor Yellow
    exit 1
}
