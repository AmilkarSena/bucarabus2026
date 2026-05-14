# 🔍 Diagnóstico de Conexión Frontend-Backend

## Script para ejecutar en la consola del navegador (F12)

Abre la consola del navegador y ejecuta estos comandos uno por uno:

### 1. Verificar variable de entorno
```javascript
console.log('VITE_API_URL:', import.meta.env.VITE_API_URL)
```

### 2. Probar conexión directa con el backend
```javascript
fetch('http://localhost:3002/api/routes')
  .then(r => r.json())
  .then(data => console.log('✅ Backend responde:', data))
  .catch(err => console.error('❌ Error:', err))
```

### 3. Probar POST directo
```javascript
fetch('http://localhost:3002/api/routes', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    id: 'RUTA_TEST',
    name: 'Ruta de Prueba',
    description: 'Prueba de conexión',
    color: '#ff0000',
    path: [[7.119, -73.122], [7.125, -73.128]],
    user: 'admin'
  })
})
  .then(r => r.json())
  .then(data => console.log('✅ Ruta creada:', data))
  .catch(err => console.error('❌ Error:', err))
```

### 4. Verificar después en la BD
Ejecuta en PostgreSQL:
```sql
SELECT * FROM tab_routes ORDER BY created_at DESC LIMIT 5;
```

---

## Comandos para verificar en el terminal

### Backend (debe estar corriendo)
```powershell
# Ver si el servidor está escuchando en el puerto 3002
netstat -an | findstr :3002
```

### Frontend (debe estar corriendo)
```powershell
# Ver si Vite está corriendo en el puerto 3000
netstat -an | findstr :3000
```

---

## Checklist de verificación

- [ ] Backend corriendo en puerto 3002
- [ ] Frontend corriendo en puerto 3000
- [ ] Variable VITE_API_URL = http://localhost:3002/api
- [ ] PostgreSQL conectado (verificar logs del backend)
- [ ] Sin errores CORS en la consola
- [ ] Sin errores de red (Network tab)
- [ ] Tabla tab_routes existe y tiene las columnas correctas

---

## Posibles problemas y soluciones

### Problema: "Failed to fetch" o "Network error"
**Solución:** Verifica que el backend esté corriendo y que no haya firewall bloqueando

### Problema: "404 Not Found"
**Solución:** La URL está mal configurada, verifica el .env y recarga con Ctrl+Shift+R

### Problema: "CORS error"
**Solución:** Verifica que el backend tenga configurado CORS correctamente

### Problema: La ruta se crea pero no aparece
**Solución:** Verifica que loadRoutes() se esté llamando después de crear

### Problema: "Endpoint no encontrado"
**Solución:** La petición no está llegando a /api/routes, sino solo a /routes
