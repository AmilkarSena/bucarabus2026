# Sistema GPS Híbrido

## 🎯 Arquitectura

```
📱 App Conductor
   ├─ Cada 5-10s   → WebSocket (tiempo real, en memoria)
   └─ Cada 10 min  → POST /api/gps/snapshot (histórico, BD)

🖥️ Monitor Live
   └─ WebSocket → Ubicaciones en tiempo real

🗄️ PostgreSQL
   ├─ tab_trips → Planificación + estado
   └─ tab_trip_gps_history → Snapshots cada 10 min (PostGIS GEOGRAPHY)
```

## 🗺️ PostGIS

La tabla usa **PostGIS** para almacenar coordenadas GPS:

- **Tipo de dato**: `GEOGRAPHY(POINT, 4326)` → Coordenadas geográficas WGS84
- **Ventajas**:
  - Funciones nativas para cálculos de distancia: `ST_DistanceSphere()`
  - Índice espacial GIST para consultas geográficas eficientes
  - Consistencia con el resto del sistema (rutas también usan PostGIS)
  - Distancias reales en metros (esféricas), no planas

## 📦 Instalación

### 1. Crear tabla en BD:
```bash
cd api
psql -U postgres -d bucarabus < database/tab_trip_gps_history.sql
```

### 2. Reiniciar API:
```bash
npm run dev
```

## 📱 Uso desde App del Conductor

### Enviar GPS en tiempo real (cada 5-10s):
```javascript
// WebSocket - NO se guarda en BD
socket.emit('gps-update', {
  id_trip: 123,
  lat: 7.119349,
  lng: -73.122742,
  speed: 45.5
})
```

### Guardar snapshot histórico (cada 10 min):
```javascript
// HTTP API - SE guarda en BD
const saveSnapshot = async () => {
  await fetch('http://localhost:3001/api/gps/snapshot', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      id_trip: 123,
      lat: 7.119349,
      lng: -73.122742,
      speed: 45.5
    })
  })
}

// Ejecutar cada 10 minutos
setInterval(saveSnapshot, 10 * 60 * 1000)
```

## 📊 Consultar Histórico

### Ver ruta completa de un viaje:
```bash
curl http://localhost:3001/api/gps/trip/123
```

Respuesta:
```json
{
  "success": true,
  "data": [
    {
      "id_gps_record": 1,
      "lat": 7.119349,
      "lng": -73.122742,
      "speed": 45.5,
      "recorded_at": "2026-02-05T14:00:00Z"
    },
    {
      "id_gps_record": 2,
      "lat": 7.120123,
      "lng": -73.123456,
      "speed": 48.2,
      "recorded_at": "2026-02-05T14:10:00Z"
    }
  ],
  "count": 2
}
```

### Estadísticas del viaje:
```bash
curl http://localhost:3001/api/gps/trip/123/statistics
```

Respuesta:
```json
{
  "success": true,
  "data": {
    "total_snapshots": 12,
    "total_distance_km": 15.8,
    "avg_speed_kmh": 42.5,
    "max_speed_kmh": 58.3,
    "total_duration_minutes": 120
  }
}
```

### Histórico de todos los viajes de un día:
```bash
curl http://localhost:3001/api/gps/date/2026-02-05
```

### Último snapshot de un viaje:
```bash
curl http://localhost:3001/api/gps/trip/123/last
```

## 🧹 Limpieza de Datos

### Eliminar registros antiguos (> 90 días):
```bash
curl -X DELETE http://localhost:3001/api/gps/cleanup?days=90
```

### Query manual en PostgreSQL:
```sql
-- Ver últimos 10 snapshots con coordenadas
SELECT 
    id_gps_record,
    id_trip,
    ST_Y(gps_location::geometry) as lat,
    ST_X(gps_location::geometry) as lng,
    speed,
    recorded_at
FROM tab_trip_gps_history 
ORDER BY recorded_at DESC 
LIMIT 10;

-- Snapshots de un viaje específico
SELECT 
    ST_Y(gps_location::geometry) as lat,
    ST_X(gps_location::geometry) as lng,
    speed,
    recorded_at
FROM tab_trip_gps_history 
WHERE id_trip = 123 
ORDER BY recorded_at ASC;

-- Contar snapshots por viaje
SELECT id_trip, COUNT(*) as total_snapshots
FROM tab_trip_gps_history
GROUP BY id_trip
ORDER BY total_snapshots DESC;

-- Calcular distancia entre dos puntos consecutivos
SELECT 
    id_gps_record,
    ST_DistanceSphere(
        LAG(gps_location) OVER (ORDER BY recorded_at),
        gps_location
    ) / 1000.0 as distance_km
FROM tab_trip_gps_history
WHERE id_trip = 123
ORDER BY recorded_at;
```

## 🎨 Visualizar Ruta en Mapa

```javascript
// Obtener histórico GPS
const response = await fetch(`/api/gps/trip/${tripId}`)
const { data: gpsHistory } = await response.json()

// Convertir a formato Leaflet
const routePath = gpsHistory.map(point => [point.lat, point.lng])

// Dibujar polyline en mapa
L.polyline(routePath, {
  color: 'blue',
  weight: 3,
  opacity: 0.7
}).addTo(map)
```

## ⚙️ Configuración

### Cambiar intervalo de guardado:

En app del conductor, cambiar de 10 min a otro valor:
```javascript
const SNAPSHOT_INTERVAL = 15 * 60 * 1000 // 15 minutos
setInterval(saveSnapshot, SNAPSHOT_INTERVAL)
```

### Cambiar período de retención:

En `gps.service.js`:
```javascript
export async function cleanupOldGPSHistory(days = 120) { // 120 días
  // ...
}
```

## 📈 Casos de Uso

### 1. Análisis de Rutas
- Ver rutas reales vs planificadas
- Identificar desvíos
- Optimizar tiempos de recorrido

### 2. Auditoría
- Verificar cumplimiento de rutas
- Resolver reclamaciones de usuarios
- Control de supervisión

### 3. Reportes
- Distancia total recorrida por bus
- Velocidades promedio por ruta
- Tiempos de viaje históricos

### 4. Mantenimiento
- Kilómetros por vehículo
- Patrones de uso
- Planificación de mantenimientos

## 🔒 Consideraciones

### Storage:
- 1 snapshot con PostGIS GEOGRAPHY(POINT) ≈ 60-80 bytes
- 50 buses × 6 snapshots/hora × 10 horas = 3,000 registros/día
- ~240 KB/día × 90 días = ~21 MB (sin índices)
- Índice GIST espacial agrega ~30-40% overhead

### Performance:
- Inserts asincrónicos (no bloquean)
- Índices optimizados:
  - B-tree en `id_trip` y `recorded_at`
  - **GIST espacial** en `gps_location` para queries geográficas
- Funciones PostGIS nativas (ST_DistanceSphere) más rápidas que cálculos manuales
- Limpieza automática programada

### Privacy:
- Datos históricos con propósito
- Retención configurable
- Acceso controlado

## ✅ Checklist de Implementación

- [ ] Ejecutar SQL: `tab_trip_gps_history.sql`
- [ ] Agregar rutas GPS en `server.js`
- [ ] Reiniciar API
- [ ] Implementar en app conductor:
  - [ ] WebSocket cada 5-10s
  - [ ] HTTP snapshot cada 10 min
- [ ] Configurar cron job de limpieza (opcional)
- [ ] Implementar visualización en Monitor
