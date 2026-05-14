#!/usr/bin/env pwsh
# Script simple para instalación rápida en servidor remoto
# Ejecuta directamente sin pedir confirmación

$env:PGPASSWORD = "Remoto1050"

Write-Host ""
Write-Host "🚀 Instalando BucaraBUS en 10.5.213.111..." -ForegroundColor Cyan
Write-Host ""

psql -h 10.5.213.111 -p 5432 -U dlastre -d db_bucarabus -f deploy-all.sql

$exitCode = $LASTEXITCODE
$env:PGPASSWORD = $null

Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "✅ Instalación exitosa" -ForegroundColor Green
} else {
    Write-Host "❌ Error en la instalación (código: $exitCode)" -ForegroundColor Red
}
Write-Host ""
