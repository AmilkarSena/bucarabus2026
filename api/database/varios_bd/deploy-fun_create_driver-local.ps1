# =============================================
# Deploy fun_create_driver v3.0 al servidor LOCAL
# =============================================
# Este script despliega la función fun_create_driver v3.0
# al servidor PostgreSQL local (localhost)
# =============================================

# Configuración del servidor local
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGDATABASE = "db_bucarabus"
$env:PGUSER = "bucarabus_user"
$env:PGPASSWORD = "bucarabus2024"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Deploy fun_create_driver v3.0" -ForegroundColor Cyan
Write-Host "Servidor: $env:PGHOST (LOCAL)" -ForegroundColor Cyan
Write-Host "Base de datos: $env:PGDATABASE" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que existe el archivo SQL
$sqlFile = Join-Path $PSScriptRoot "fun_create_driver.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Host "❌ ERROR: No se encuentra el archivo fun_create_driver.sql" -ForegroundColor Red
    exit 1
}

Write-Host "📄 Archivo SQL encontrado: $sqlFile" -ForegroundColor Green
Write-Host ""

# Ejecutar el script SQL
Write-Host "🚀 Desplegando función..." -ForegroundColor Yellow
try {
    psql -f $sqlFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Función desplegada exitosamente!" -ForegroundColor Green
        Write-Host ""
        
        # Verificar la función
        Write-Host "🔍 Verificando función creada..." -ForegroundColor Yellow
        $query = "SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_name = 'fun_create_driver' AND routine_schema = 'public';"
        psql -c $query
        
        Write-Host ""
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host "✅ DEPLOY COMPLETADO" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Cyan
        
    } else {
        Write-Host ""
        Write-Host "❌ ERROR al desplegar la función" -ForegroundColor Red
        Write-Host "Código de salida: $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR: $_" -ForegroundColor Red
    exit 1
}
