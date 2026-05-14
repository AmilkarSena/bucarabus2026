# 📱 Guía de Acceso desde Celular

## ✅ Configuración Completa

Tu sistema BucaraBus ya está configurado para acceso desde celular en tu red WiFi local.

### 🌐 URLs de Acceso

**Desde tu PC (desarrollo):**
- Frontend: `http://localhost:3002`
- API: `http://localhost:3001/api`

**Desde tu celular (misma red WiFi):**
- Frontend: `http://192.168.1.18:3002`
- API: `http://192.168.1.18:3001/api`

---

## 🚀 Pasos para Acceder desde el Celular

### 1️⃣ **Asegúrate de que ambos servidores estén corriendo**

En **Terminal 1** (Frontend - Vite):
```powershell
cd C:\Users\dlast\Documents\previous_version\vue-bucarabus
npm run dev
```

En **Terminal 2** (Backend - API):
```powershell
cd C:\Users\dlast\Documents\previous_version\vue-bucarabus\api
npm run dev
```

### 2️⃣ **Verifica que tu PC y celular estén en la misma red WiFi**
- PC: Conectado a WiFi (192.168.1.18)
- Celular: Conectado a la **misma red WiFi**

### 3️⃣ **Permitir conexiones en el Firewall de Windows**

Si es la primera vez, es posible que Windows te pida permiso. Asegúrate de:
- ✅ Permitir acceso a **Node.js** en redes privadas
- ✅ Permitir puertos **3001** y **3002**

**Si necesitas configurar manualmente:**
```powershell
# Abrir PowerShell como Administrador y ejecutar:
New-NetFirewallRule -DisplayName "BucaraBus API" -Direction Inbound -LocalPort 3001 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "BucaraBus Frontend" -Direction Inbound -LocalPort 3002 -Protocol TCP -Action Allow
```

### 4️⃣ **Acceder desde el navegador del celular**

Abre el navegador de tu celular (Chrome, Safari, etc.) y ve a:
```
http://192.168.1.18:3002
```

---

## 🔧 Solución de Problemas

### ❌ No carga la página
**Posible causa:** Firewall bloqueando las conexiones

**Solución:**
1. Ejecuta los comandos del firewall (paso 3)
2. Reinicia los servidores
3. Intenta de nuevo desde el celular

### ❌ La página carga pero no muestra datos
**Posible causa:** Problemas de conexión con la API o WebSocket

**Solución:**
1. Abre la consola del navegador en el celular (Chrome DevTools remoto)
2. Verifica que las URLs de conexión sean correctas
3. Revisa que la API esté corriendo en la PC

**Verificar en la consola del navegador:**
```javascript
console.log(import.meta.env.VITE_API_URL)
// Debería mostrar: http://192.168.1.18:3001/api

console.log(import.meta.env.VITE_WS_URL)
// Debería mostrar: http://192.168.1.18:3001
```

### ❌ La IP de la PC cambió
**Posible causa:** Tu router asigna IPs dinámicas (DHCP)

**Solución:**
1. Obtener la nueva IP:
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -like '192.168.*'} | Select-Object IPAddress
```

2. Actualizar el archivo `.env`:
```env
VITE_API_URL=http://NUEVA_IP:3001/api
VITE_WS_URL=http://NUEVA_IP:3001
```

3. Reiniciar el servidor Vite (frontend)

---

## 📝 Archivos Configurados

Los siguientes archivos fueron actualizados para permitir acceso desde celular:

### `.env` (Frontend)
```env
VITE_API_URL=http://192.168.1.18:3001/api
VITE_WS_URL=http://192.168.1.18:3001
```

### `vite.config.js`
```javascript
server: {
  host: '0.0.0.0',  // ← Acepta conexiones de toda la red
  port: 3002
}
```

### `api/server.js`
```javascript
httpServer.listen(PORT, '0.0.0.0', () => {
  // ← Acepta conexiones de toda la red
})
```

---

## 🔒 Seguridad

⚠️ **IMPORTANTE:** Esta configuración es solo para desarrollo en red local.

**NO uses esta configuración en producción** sin:
- HTTPS (SSL/TLS)
- Autenticación robusta
- Rate limiting
- CORS configurado correctamente
- Firewall adecuado

---

## 🌍 Para Acceso Público (Opcional)

Si necesitas acceder desde fuera de tu red WiFi, considera usar:

### Opción 1: ngrok (Recomendado para pruebas)
```bash
# Instalar ngrok
# Descargar desde: https://ngrok.com/download

# Exponer el frontend
ngrok http 3002

# Exponer el backend (en otra terminal)
ngrok http 3001
```

### Opción 2: Configurar Port Forwarding en tu Router
1. Accede a tu router (generalmente `192.168.1.1`)
2. Configura port forwarding para puertos 3001 y 3002
3. Usa tu IP pública para acceder

---

## ✅ Verificación Final

1. Servidor backend corriendo: ✓
2. Servidor frontend corriendo: ✓
3. PC y celular en la misma WiFi: ✓
4. Firewall permitiendo conexiones: ✓
5. Acceso desde celular: `http://192.168.1.18:3002` ✓

---

**¡Listo para usar desde tu celular! 🎉**
