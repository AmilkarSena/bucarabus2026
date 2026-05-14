Write-Host "🚀 Iniciando compilación de todas las apps..." -ForegroundColor Cyan

# 1. Compilar Admin (Raíz)
Write-Host "`n--------------------------------------"
Write-Host "📦 Compilando App ADMIN..."
Write-Host "--------------------------------------"
npm install
npm run build

# 2. Compilar Pasajero
Write-Host "`n--------------------------------------"
Write-Host "📦 Compilando App PASAJERO..."
Write-Host "--------------------------------------"
Set-Location apps/passenger
npm install
npm run build
Set-Location ../..

# 3. Compilar Conductor
Write-Host "`n--------------------------------------"
Write-Host "📦 Compilando App CONDUCTOR..."
Write-Host "--------------------------------------"
Set-Location apps/driver
npm install
npm run build
Set-Location ../..

Write-Host "`n--------------------------------------" -ForegroundColor Green
Write-Host "✅ ¡Todas las apps han sido compiladas!" -ForegroundColor Green
Write-Host "📂 Revisa las carpetas 'dist' en la raíz y dentro de cada app."
Write-Host "--------------------------------------"
