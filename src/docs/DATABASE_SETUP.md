# 🗄️ Configuración de PostgreSQL con PostGIS para BucaraBus

## 📋 Requisitos Previos

- PostgreSQL 12+ instalado
- PostGIS extension
- Node.js 18+

---

## 🛠️ 1. Crear la Base de Datos

```sql
-- Crear base de datos
CREATE DATABASE bucarabus_db;

-- Conectar a la base de datos
\c bucarabus_db

-- Habilitar extensión PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;

-- Verificar instalación
SELECT PostGIS_Version();
```

---

## 📊 2. Crear Tablas

### **Tabla: routes**

```sql
-- ✅ Ya existe en tu base de datos como tab_routes
-- No necesitas crear esta tabla, solo agregar campos opcionales:

ALTER TABLE tab_routes 
ADD COLUMN IF NOT EXISTS fare INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS frequency INTEGER DEFAULT 15,
ADD COLUMN IF NOT EXISTS visible BOOLEAN DEFAULT false;

-- Los índices espaciales ya existen:
-- CREATE INDEX idx_routes_path ON tab_routes USING GIST (path_route);
```

### **Tabla: route_stops (Paradas)**

```sql
-- Crear tabla de paradas de ruta
CREATE TABLE route_stops (
    id SERIAL PRIMARY KEY,
    route_id VARCHAR(20) REFERENCES routes(id) ON DELETE CASCADE,
    stop_order INTEGER NOT NULL,
    name VARCHAR(255),
    location GEOMETRY(Point, 4326),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, stop_order)
);

-- Índice espacial
CREATE INDEX idx_route_stops_location ON route_stops USING GIST (location);
```

### **Tabla: route_buses (Asignación de buses)**

```sql
-- Crear tabla de buses asignados a rutas
CREATE TABLE route_buses (
    id SERIAL PRIMARY KEY,
    route_id VARCHAR(20) REFERENCES routes(id) ON DELETE CASCADE,
    bus_id VARCHAR(20) NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, bus_id)
);
```

---

## 🔧 3. Funciones Útiles

### **Trigger para updated_at**

```sql
-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a la tabla routes
CREATE TRIGGER update_routes_updated_at 
    BEFORE UPDATE ON routes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
```

### **Función para calcular distancia de ruta**

```sql
-- Calcular longitud de ruta en kilómetros
CREATE OR REPLACE FUNCTION get_route_distance(route_geometry GEOMETRY)
RETURNS NUMERIC AS $$
BEGIN
    RETURN ST_Length(ST_Transform(route_geometry, 3857)) / 1000;
END;
$$ LANGUAGE plpgsql;
```

---

## 📝 4. Datos de Ejemplo (Opcional)

```sql
-- Insertar ruta de ejemplo
INSERT INTO routes (id, name, color, fare, frequency, description, visible, geometry)
VALUES (
    'RUTA_01',
    'Ruta Centro',
    '#3b82f6',
    2800,
    15,
    'Ruta principal del centro de Bucaramanga',
    true,
    ST_GeomFromText('LINESTRING(-73.122 7.119, -73.128 7.125)', 4326)
);

-- Insertar paradas
INSERT INTO route_stops (route_id, stop_order, name, location)
VALUES 
    ('RUTA_01', 1, 'Parque Santander', ST_GeomFromText('POINT(-73.122 7.119)', 4326)),
    ('RUTA_01', 2, 'Centro Comercial', ST_GeomFromText('POINT(-73.125 7.122)', 4326)),
    ('RUTA_01', 3, 'Terminal', ST_GeomFromText('POINT(-73.128 7.125)', 4326));
```

---

## 🔍 5. Consultas Útiles

### **Obtener todas las rutas con geometría**

```sql
SELECT 
    id,
    name,
    color,
    fare,
    frequency,
    description,
    visible,
    ST_AsGeoJSON(geometry) as geojson,
    get_route_distance(geometry) as distance_km,
    created_at
FROM routes
ORDER BY name;
```

### **Obtener ruta con paradas**

```sql
SELECT 
    r.id,
    r.name,
    r.color,
    ST_AsGeoJSON(r.geometry) as route_geojson,
    json_agg(
        json_build_object(
            'order', rs.stop_order,
            'name', rs.name,
            'location', ST_AsGeoJSON(rs.location)
        ) ORDER BY rs.stop_order
    ) as stops
FROM routes r
LEFT JOIN route_stops rs ON r.id = rs.route_id
WHERE r.id = 'RUTA_01'
GROUP BY r.id, r.name, r.color, r.geometry;
```

### **Buscar rutas cercanas a un punto**

```sql
-- Rutas dentro de 1km de un punto
SELECT 
    id,
    name,
    ST_Distance(
        ST_Transform(geometry, 3857),
        ST_Transform(ST_GeomFromText('POINT(-73.125 7.120)', 4326), 3857)
    ) / 1000 as distance_km
FROM routes
WHERE ST_DWithin(
    ST_Transform(geometry, 3857),
    ST_Transform(ST_GeomFromText('POINT(-73.125 7.120)', 4326), 3857),
    1000
)
ORDER BY distance_km;
```

---

## 🔐 6. Usuario y Permisos

```sql
-- Crear usuario para la aplicación
CREATE USER bucarabus_user WITH PASSWORD 'tu_password_seguro';

-- Otorgar permisos
GRANT CONNECT ON DATABASE bucarabus_db TO bucarabus_user;
GRANT USAGE ON SCHEMA public TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO bucarabus_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO bucarabus_user;

-- Permisos futuros
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
GRANT ALL PRIVILEGES ON TABLES TO bucarabus_user;
```

---

## 📦 7. Backup y Restore

### **Backup**

```bash
# Backup completo
pg_dump -U postgres bucarabus_db > bucarabus_backup.sql

# Backup solo estructura
pg_dump -U postgres -s bucarabus_db > bucarabus_schema.sql

# Backup solo datos
pg_dump -U postgres -a bucarabus_db > bucarabus_data.sql
```

### **Restore**

```bash
# Restaurar backup
psql -U postgres bucarabus_db < bucarabus_backup.sql
```

---

## 🌐 8. Variables de Entorno (.env)

```env
# PostgreSQL Connection
DB_HOST=localhost
DB_PORT=5432
DB_NAME=bucarabus_db
DB_USER=bucarabus_user
DB_PASSWORD=tu_password_seguro

# Pool Configuration
DB_POOL_MIN=2
DB_POOL_MAX=10

# Application
NODE_ENV=development
PORT=3000
```

---

## ✅ Verificación

```sql
-- Verificar extensiones instaladas
SELECT * FROM pg_extension WHERE extname = 'postgis';

-- Verificar tablas creadas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;

-- Verificar índices espaciales
SELECT tablename, indexname, indexdef 
FROM pg_indexes 
WHERE schemaname = 'public' 
AND indexdef LIKE '%GIST%';
```

---

## 📚 Documentación de PostGIS

- **Tipos de geometría:** Point, LineString, Polygon, MultiPoint, MultiLineString, MultiPolygon
- **SRID 4326:** Sistema de coordenadas WGS84 (usado por GPS)
- **SRID 3857:** Web Mercator (usado para cálculos de distancia)

### **Funciones PostGIS útiles:**

- `ST_GeomFromText()` - Crear geometría desde WKT
- `ST_AsGeoJSON()` - Convertir a GeoJSON
- `ST_Transform()` - Transformar entre SRIDs
- `ST_Distance()` - Calcular distancia
- `ST_DWithin()` - Buscar dentro de radio
- `ST_Length()` - Longitud de LineString
- `ST_Area()` - Área de Polygon

---

**Base de datos lista para usar! 🎉**
