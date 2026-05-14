# Script para compilar todas las aplicaciones de BucaraBus
# Ejecuta esto en tu PC local antes de subir a la VM

echo "🚀 Iniciando compilación de todas las apps..."

# 1. Compilar Admin (Raíz)
echo "--------------------------------------"
echo "📦 Compilando App ADMIN..."
echo "--------------------------------------"
npm install
npm run build

# 2. Compilar Pasajero
echo "--------------------------------------"
echo "📦 Compilando App PASAJERO..."
echo "--------------------------------------"
cd apps/passenger
npm install
npm run build
cd ../..

# 3. Compilar Conductor
echo "--------------------------------------"
echo "📦 Compilando App CONDUCTOR..."
echo "--------------------------------------"
cd apps/driver
npm install
npm run build
cd ../..

echo "--------------------------------------"
echo "✅ ¡Todas las apps han sido compiladas!"
echo "📂 Revisa las carpetas 'dist' en la raíz y dentro de cada app."
echo "--------------------------------------"
