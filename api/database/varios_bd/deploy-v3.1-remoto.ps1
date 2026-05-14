# =============================================
# Deploy de Funciones v3.1 al Servidor Remoto
# =============================================
# fun_create_user v3.1 - Table-level lock (LOCK TABLE)
# fun_create_driver v3.1 - Table-level lock (LOCK TABLE)
# =============================================

$env:PGPASSWORD = "Remoto1050"
$DB_HOST = "10.5.213.111"
$DB_PORT = "5432"
$DB_NAME = "db_bucarabus"
$DB_USER = "dlastre"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DEPLOY: Funciones v3.1 (LOCK TABLE)" -ForegroundColor Cyan
Write-Host "Servidor: $DB_HOST" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# 1. Desplegar fun_create_user v3.1
Write-Host "`n[1/2] Desplegando fun_create_user v3.1..." -ForegroundColor Green
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "fun_create_user.sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✅ fun_create_user v3.1 desplegada" -ForegroundColor Green
} else {
    Write-Host "    ❌ Error al desplegar fun_create_user" -ForegroundColor Red
    exit 1
}

# 2. Desplegar fun_create_driver v3.1
Write-Host "`n[2/2] Desplegando fun_create_driver v3.1..." -ForegroundColor Green
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "fun_create_driver.sql"

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✅ fun_create_driver v3.1 desplegada" -ForegroundColor Green
} else {
    Write-Host "    ❌ Error al desplegar fun_create_driver" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✅ DEPLOY COMPLETADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "`nFunciones desplegadas:" -ForegroundColor White
Write-Host "  • fun_create_user v3.1 (con LOCK TABLE)" -ForegroundColor White
Write-Host "  • fun_create_driver v3.1 (con LOCK TABLE)" -ForegroundColor White
Write-Host "`nProtección: Table-level lock para prevenir colisiones" -ForegroundColor Yellow

Remove-Item Env:\PGPASSWORD
