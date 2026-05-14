# =============================================
# Deploy fun_create_user v3.0 al servidor LOCAL
# =============================================
# Este script despliega la función fun_create_user v3.0
# al servidor PostgreSQL local (localhost)
# =============================================

# Configuración del servidor local
$env:PGHOST = "localhost"
$env:PGPORT = "5432"
$env:PGDATABASE = "db_bucarabus"
$env:PGUSER = "bucarabus_user"
$env:PGPASSWORD = "bucarabus2024"

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Deploy fun_create_user v3.0" -ForegroundColor Cyan
Write-Host "Servidor: $env:PGHOST (LOCAL)" -ForegroundColor Cyan
Write-Host "Base de datos: $env:PGDATABASE" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Verificar que existe el archivo SQL
$sqlFile = Join-Path $PSScriptRoot "deploy-fun_create_user-v3.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Host "❌ ERROR: No se encuentra el archivo deploy-fun_create_user-v3.sql" -ForegroundColor Red
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
        $query = "SELECT routine_name, routine_type FROM information_schema.routines WHERE routine_name = 'fun_create_user' AND routine_schema = 'public';"
        psql -c $query
        
        Write-Host ""
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host "✅ DEPLOY COMPLETADO" -ForegroundColor Green
        Write-Host "================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Ahora puedes probar creando un usuario:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  cd ..\api" -ForegroundColor White
        Write-Host "  node -e `"const bcrypt = require('bcrypt'); bcrypt.hash('Admin123', 10).then(h => console.log(h));`"" -ForegroundColor White
        Write-Host ""
        Write-Host "Luego en pgAdmin ejecuta:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  SELECT * FROM fun_create_user(" -ForegroundColor White
        Write-Host "    'admin@bucarabus.local'," -ForegroundColor White
        Write-Host "    '\$2b\$10\$...',  -- Hash generado arriba" -ForegroundColor White
        Write-Host "    'Administrador'," -ForegroundColor White
        Write-Host "    1735689600,  -- Sistema" -ForegroundColor White
        Write-Host "    NULL" -ForegroundColor White
        Write-Host "  );" -ForegroundColor White
        Write-Host ""
        
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
