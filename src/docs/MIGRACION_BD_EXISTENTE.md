# 🔄 Migración a Base de Datos Existente de BucaraBus

Esta guía te ayudará a adaptar el sistema Vue a tu base de datos PostgreSQL + PostGIS existente.

---

## 📊 Diferencias entre Esquemas

### **Esquema Original vs Tu Esquema:**

| Original | Tu BD | Cambio |
|----------|-------|--------|
| `routes` | `tab_routes` | Nombre de tabla |
| `id` (VARCHAR) | `id_route` (DECIMAL) | Tipo y nombre |
| `name` | `name_route` | Nombre de campo |
| `geometry` | `path_route` | Nombre de geometría |
| `description` | `descrip_route` | Nombre de campo |
| `color` | `color_route` | Nombre de campo |
| - | `start_area` | Campo adicional (Polygon) |
| - | `end_area` | Campo adicional (Polygon) |
| - | `user_create` | Campo adicional (auditoría) |
| - | `user_update` | Campo adicional (auditoría) |
| `visible` (nuevo) | - | Agregar con ALTER TABLE |
| `fare` (nuevo) | - | Agregar con ALTER TABLE |
| `frequency` (nuevo) | - | Agregar con ALTER TABLE |

---

## 🛠️ Paso 1: Agregar Campos Faltantes

Ejecuta estos comandos SQL en tu base de datos:

```sql
-- Conectar a la base de datos
\c bucarabus_db

-- Agregar campos opcionales para el frontend
ALTER TABLE tab_routes 
ADD COLUMN IF NOT EXISTS fare INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS frequency INTEGER DEFAULT 15,
ADD COLUMN IF NOT EXISTS visible BOOLEAN DEFAULT FALSE;

-- Verificar cambios
\d tab_routes
```

---

## 📂 Paso 2: Configurar Variables de Entorno

### **Backend API (.env):**

```env
# PostgreSQL Connection - TU BASE DE DATOS
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bucarabus_db
DB_USER=tu_usuario_postgres
DB_PASSWORD=tu_password

# Pool Configuration
DB_POOL_MIN=2
DB_POOL_MAX=10

# Application
NODE_ENV=development
PORT=3002
FRONTEND_URL=http://localhost:3000
```

---

## 🔄 Paso 3: Mapeo de Campos

El backend traducirá automáticamente entre tu esquema y el frontend:

```javascript
// Frontend envía:
{
  id: "RUTA_01",
  name: "Ruta Centro",
  color: "#3b82f6",
  path: [[-73.122, 7.119], [-73.125, 7.122]]
}

// Backend convierte a:
INSERT INTO tab_routes (
  id_route,        -- 1 (extrae número de "RUTA_01")
  name_route,      -- "Ruta Centro"
  color_route,     -- "#3b82f6"
  path_route,      -- ST_GeomFromText('LINESTRING(...)')
  user_create      -- "admin" (del contexto)
)

// Backend devuelve al frontend:
{
  id: "RUTA_01",   -- Reformatea de 1 a "RUTA_01"
  name: "Ruta Centro",
  color: "#3b82f6",
  path: [[-73.122, 7.119], [-73.125, 7.122]]
}
```

---

## 🎯 Paso 4: Relaciones con Otras Tablas

### **Rutas ↔ Viajes (trips):**

Tu BD ya tiene la relación:

```sql
CREATE TABLE trips (
    id_trip BIGINT NOT NULL,
    id_route DECIMAL(3,0) NOT NULL,  -- ← Relación con tab_routes
    id_bus VARCHAR(50) NOT NULL,
    scheduled_start_time TIMESTAMPTZ NOT NULL,
    status_trip VARCHAR DEFAULT 'assigned',
    FOREIGN KEY (id_route) REFERENCES tab_routes(id_route)
);
```

El backend puede obtener viajes por ruta:

```javascript
GET /api/routes/RUTA_01/trips
```

### **Rutas ↔ Buses (tab_buses):**

A través de la tabla `trips`:

```javascript
// Obtener buses asignados a una ruta
GET /api/routes/RUTA_01/buses
```

---

## 📝 Paso 5: Formato de IDs

### **Conversión Automática:**

- **Frontend:** Usa `"RUTA_01"`, `"RUTA_02"`, etc.
- **Backend:** Convierte a `1`, `2` para la BD
- **BD:** Almacena como `DECIMAL(3,0)`

```javascript
// Función de conversión en el backend:
const routeIdToNumber = (id) => parseInt(id.replace('RUTA_', ''))
const numberToRouteId = (num) => `RUTA_${String(num).padStart(2, '0')}`

// Ejemplos:
routeIdToNumber("RUTA_01")  // → 1
routeIdToNumber("RUTA_15")  // → 15
numberToRouteId(1)          // → "RUTA_01"
numberToRouteId(15)         // → "RUTA_15"
```

---

## 🗺️ Paso 6: Geometrías PostGIS

### **LineString (Rutas):**

```sql
-- Insertar ruta
INSERT INTO tab_routes (id_route, name_route, path_route)
VALUES (
  1,
  'Ruta Centro',
  ST_GeomFromText('LINESTRING(-73.122 7.119, -73.125 7.122)', 4326)
);

-- Consultar como GeoJSON
SELECT 
  id_route,
  name_route,
  ST_AsGeoJSON(path_route) as path
FROM tab_routes;
```

### **Polygon (Áreas de Inicio/Fin):**

```sql
-- Si quieres agregar áreas de inicio/fin:
UPDATE tab_routes
SET start_area = ST_GeomFromText('POLYGON((...coordenadas...))', 4326)
WHERE id_route = 1;
```

---

## 🔐 Paso 7: Auditoría de Usuarios

Tu BD requiere `user_create` y `user_update`. El backend debe capturar el usuario actual:

```javascript
// En el backend (routes.service.js):
async createRoute(routeData, userId) {
  const query = `
    INSERT INTO tab_routes (
      id_route, 
      name_route, 
      path_route,
      user_create    -- ← Importante
    )
    VALUES ($1, $2, ST_GeomFromText($3, 4326), $4)
  `
  
  await pool.query(query, [id, name, wkt, userId])
}
```

**Opciones para obtener el usuario:**

1. **Desde sesión/token JWT** (recomendado)
2. **Hardcoded temporalmente:** `'admin'`
3. **Desde header HTTP:** `req.headers['x-user-id']`

---

## 🧪 Paso 8: Probar la Integración

### **1. Verificar BD:**

```sql
-- Ver rutas actuales
SELECT 
  id_route,
  name_route,
  ST_AsText(path_route) as path_wkt,
  color_route,
  status_route
FROM tab_routes;
```

### **2. Iniciar Backend:**

```bash
cd api
copy .env.example .env
# Editar .env con tus credenciales
npm install
npm run dev
```

### **3. Probar Endpoint:**

```bash
# Health check
curl http://localhost:3002/health

# Obtener todas las rutas
curl http://localhost:3002/api/routes

# Crear nueva ruta (con Postman o curl)
curl -X POST http://localhost:3002/api/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Ruta Test",
    "color": "#ff0000",
    "description": "Ruta de prueba",
    "path": [[-73.122, 7.119], [-73.125, 7.122]],
    "user": "admin"
  }'
```

### **4. Iniciar Frontend:**

```bash
cd vue-bucarabus
npm run dev
```

Navega a `http://localhost:3000` y prueba:
- Crear nueva ruta dibujando en el mapa
- Ver lista de rutas
- Editar/eliminar rutas

---

## 📊 Paso 9: Verificar Datos en PostgreSQL

Después de crear una ruta desde el frontend:

```sql
-- Verificar que se guardó
SELECT 
  id_route,
  name_route,
  color_route,
  ST_AsText(path_route) as path,
  ST_AsGeoJSON(path_route) as geojson,
  fare,
  frequency,
  visible,
  status_route,
  created_at,
  user_create
FROM tab_routes
ORDER BY created_at DESC
LIMIT 1;

-- Calcular distancia
SELECT 
  id_route,
  name_route,
  ST_Length(ST_Transform(path_route, 3857)) / 1000 as km
FROM tab_routes;
```

---

## 🔄 Paso 10: Migración de Datos Existentes

Si ya tienes rutas en tu BD, el frontend las cargará automáticamente:

```sql
-- Asegurar que los campos nuevos tengan valores por defecto
UPDATE tab_routes
SET 
  fare = COALESCE(fare, 0),
  frequency = COALESCE(frequency, 15),
  visible = COALESCE(visible, FALSE)
WHERE status_route = TRUE;
```

---

## ⚠️ Consideraciones Importantes

### **1. IDs Numéricos vs String:**

El frontend usa `"RUTA_XX"` pero tu BD usa números. El backend hace la conversión automática.

### **2. Auditoría:**

Necesitas pasar el usuario actual. Opciones:

```javascript
// Opción 1: Hardcoded (desarrollo)
const currentUser = 'admin'

// Opción 2: Desde JWT (producción)
const currentUser = req.user.id_user

// Opción 3: Desde header (temporal)
const currentUser = req.headers['x-user-id'] || 'system'
```

### **3. Soft Delete:**

Tu BD usa `status_route` para "borrado lógico". El backend hace:

```sql
-- En lugar de DELETE FROM...
UPDATE tab_routes SET status_route = FALSE WHERE id_route = $1
```

### **4. Índices Espaciales:**

Ya tienes el índice GIST:

```sql
CREATE INDEX idx_routes_path ON tab_routes USING GIST (path_route);
```

Esto hace que las búsquedas geoespaciales sean rápidas.

---

## 📄 Archivos Adaptados

1. **`api/services/routes.service.js`** - Servicio adaptado a `tab_routes`
2. **`api/routes/routes.routes.js`** - Endpoints sin cambios
3. **`api/config/database.js`** - Conexión a tu BD
4. **`src/stores/routes.js`** - Store sin cambios (usa API)
5. **`src/api/routes.js`** - Cliente API sin cambios

---

## ✅ Checklist de Migración

- [ ] Agregar campos `fare`, `frequency`, `visible` a `tab_routes`
- [ ] Configurar `.env` con credenciales de PostgreSQL
- [ ] Instalar dependencias backend: `cd api && npm install`
- [ ] Instalar dependencias frontend: `npm install axios`
- [ ] Iniciar backend: `cd api && npm run dev`
- [ ] Iniciar frontend: `npm run dev`
- [ ] Probar crear ruta desde el mapa
- [ ] Verificar datos en PostgreSQL
- [ ] Configurar usuario actual para auditoría

---

**¡Listo para usar tu base de datos existente! 🎉**
