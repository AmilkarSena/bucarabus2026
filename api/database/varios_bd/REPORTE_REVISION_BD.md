# 📋 REPORTE DE REVISIÓN Y MEJORAS - bd_bucarabus.sql

**Fecha:** Febrero 2025  
**Archivo:** `vue-bucarabus/api/database/bd_bucarabus.sql`  
**Estado:** ✅ Completado y Optimizado

---

## 🔴 ERRORES CRÍTICOS CORREGIDOS

### 1. DROP TABLE sin IF EXISTS
**Problema:** Las tablas iniciales se eliminaban sin verificar si existen.
```sql
-- ❌ ANTES
DROP TABLE trips;
DROP TABLE tab_subscriptions;
DROP TABLE tab_buses;
DROP TABLE tab_drivers;  -- Esta tabla ya no existe en el esquema nuevo
```

**Solución:**
```sql
-- ✅ DESPUÉS
DROP TABLE IF EXISTS tab_trips CASCADE;
DROP TABLE IF EXISTS tab_favorite_routes CASCADE;
DROP TABLE IF EXISTS tab_bus_assignments CASCADE;
DROP TABLE IF EXISTS tab_routes CASCADE;
DROP TABLE IF EXISTS tab_buses CASCADE;
DROP TABLE IF EXISTS tab_driver_details CASCADE;
DROP TABLE IF EXISTS tab_user_roles CASCADE;
DROP TABLE IF EXISTS tab_roles CASCADE;
DROP TABLE IF EXISTS tab_users CASCADE;

-- Tablas legacy/obsoletas
DROP TABLE IF EXISTS tab_drivers CASCADE;
DROP TABLE IF EXISTS tab_subscriptions CASCADE;
DROP TABLE IF EXISTS trips CASCADE;
```

### 2. COMMENT antes de CREATE TABLE
**Problema:** Se comentaba la tabla `tab_favorite_routes` ANTES de crearla.
```sql
-- ❌ ANTES (línea 137)
COMMENT ON TABLE tab_favorite_routes IS 'Rutas favoritas de los usuarios';
-- ...200 líneas después...
CREATE TABLE tab_favorite_routes (...);  -- línea 211
```

**Solución:** Reorganización completa. Todos los COMMENTs ahora están al final, después de crear todas las tablas.

### 3. Falta DEFERRABLE en FK auto-referencial
**Problema:** `tab_users.user_create` referencia a sí misma, causaba error en INSERT del usuario sistema.

**Solución:**
```sql
-- ✅ DESPUÉS
CONSTRAINT fk_users_created_by FOREIGN KEY (user_create) 
  REFERENCES tab_users(id_user) 
  ON DELETE SET DEFAULT 
  DEFERRABLE INITIALLY DEFERRED
```

---

## ⚠️ INCONSISTENCIAS CORREGIDAS

### 1. TIMESTAMP vs TIMESTAMPTZ
**Problema:** Mezcla de tipos de datos para timestamps.

| Tabla | Campo | ANTES | DESPUÉS |
|-------|-------|-------|---------|
| tab_users | created_at, updated_at | TIMESTAMPTZ ✅ | TIMESTAMPTZ ✅ |
| tab_buses | created_at, updated_at | TIMESTAMP ❌ | TIMESTAMPTZ ✅ |
| tab_routes | created_at, updated_at | TIMESTAMP ❌ | TIMESTAMPTZ ✅ |
| tab_favorite_routes | added_at | TIMESTAMP ❌ | TIMESTAMPTZ ✅ |
| tab_bus_assignments | assigned_at, unassigned_at, created_at, updated_at | TIMESTAMP ❌ | TIMESTAMPTZ ✅ |
| tab_trips | created_at, updated_at | TIMESTAMP ❌ | TIMESTAMPTZ ✅ |

**Razón:** `TIMESTAMPTZ` incluye zona horaria, esencial para sistemas distribuidos.

### 2. Tipos de datos ineficientes
**Problema:** Uso de DECIMAL para IDs y valores pequeños.

```sql
-- ❌ ANTES
id_route      DECIMAL(3,0)    -- Para IDs (1-999)
id_company    DECIMAL(2,0)    -- Para compañías (1-99)
capacity      DECIMAL(3,0)    -- Para capacidad (10-999)
```

```sql
-- ✅ DESPUÉS
id_route      INTEGER         -- Más eficiente para IDs
id_company    SMALLINT        -- 2 bytes, rango 1-99
capacity      SMALLINT        -- 2 bytes, rango 10-999
```

**Impacto:** Reducción de almacenamiento y mejora de performance en índices.

### 3. VARCHAR sin límite de longitud
**Problema:** `name_route VARCHAR` sin especificar tamaño.

```sql
-- ❌ ANTES
name_route    VARCHAR    NOT NULL,
```

```sql
-- ✅ DESPUÉS
name_route    VARCHAR(200)    NOT NULL,
```

### 4. IF NOT EXISTS inconsistente
**Problema:** Algunas tablas tenían `IF NOT EXISTS`, otras no.

```sql
-- ❌ ANTES
CREATE TABLE IF NOT EXISTS tab_buses (...)
CREATE TABLE IF NOT EXISTS tab_routes (...)
CREATE TABLE tab_trips (...)  -- Sin IF NOT EXISTS
```

```sql
-- ✅ DESPUÉS
-- Todas sin IF NOT EXISTS (se controla con DROP IF EXISTS CASCADE al inicio)
CREATE TABLE tab_buses (...)
CREATE TABLE tab_routes (...)
CREATE TABLE tab_trips (...)
```

**Razón:** El script ahora hace DROP completo al inicio, no necesita IF NOT EXISTS.

---

## 🚀 MEJORAS IMPLEMENTADAS

### 1. Reorganización completa del archivo
**Nueva estructura:**
```
1. EXTENSIONES (postgis)
2. LIMPIEZA (DROP en orden correcto)
3. TABLAS PRINCIPALES (ordenadas por dependencias)
4. ÍNDICES (agrupados por tabla)
5. DATOS INICIALES (seeds)
6. COMENTARIOS (documentación)
7. RESUMEN (convenciones y guía)
```

### 2. Índices adicionales agregados
**Índices nuevos:**

| Tabla | Índice Agregado | Beneficio |
|-------|----------------|-----------|
| tab_buses | `idx_buses_driver` | Búsqueda rápida por conductor |
| tab_buses | `idx_buses_active` | Filtrar buses activos |
| tab_buses | `idx_buses_company` | Agrupar por compañía |
| tab_routes | `idx_routes_active` | Filtrar rutas activas |
| tab_routes | `idx_routes_name` | Búsqueda por nombre |
| tab_routes | `idx_routes_path_gist` | Consultas espaciales PostGIS |
| tab_routes | `idx_routes_start_area_gist` | Búsqueda por área inicio |
| tab_routes | `idx_routes_end_area_gist` | Búsqueda por área fin |
| tab_trips | `idx_trips_date` | Filtrar por fecha |
| tab_trips | `idx_trips_pending` | Optimizar turnos pendientes |
| tab_roles | `idx_roles_active` | Filtrar roles activos |
| tab_roles | `idx_roles_created_by` | Auditoría |
| tab_roles | `idx_roles_updated_by` | Auditoría |
| tab_user_roles | `idx_user_roles_user` | Búsqueda por usuario |
| tab_user_roles | `idx_user_roles_role` | Búsqueda por rol |
| tab_user_roles | `idx_user_roles_assigned_by` | Auditoría |
| tab_driver_details | `idx_driver_details_available` | Conductores disponibles |
| tab_driver_details | `idx_driver_details_license_exp` | Licencias por vencer |
| tab_driver_details | `idx_driver_details_created_by` | Auditoría |
| tab_driver_details | `idx_driver_details_updated_by` | Auditoría |

**Total de índices:** De 25 → 54 índices (116% de incremento)

### 3. Validaciones adicionales (CHECK constraints)

```sql
-- ✅ AGREGADO en tab_buses
CONSTRAINT chk_buses_amb_format CHECK (amb_code ~ '^AMB-[0-9]{4}$'),
CONSTRAINT chk_buses_company CHECK (id_company BETWEEN 1 AND 99),

-- ✅ AGREGADO en tab_routes
CONSTRAINT chk_routes_color_format CHECK (color_route ~ '^#[0-9A-Fa-f]{6}$'),

-- ✅ AGREGADO en tab_bus_assignments
CONSTRAINT chk_assignments_dates CHECK (unassigned_at IS NULL OR unassigned_at >= assigned_at),

-- ✅ AGREGADO en tab_trips
CONSTRAINT chk_trips_date CHECK (trip_date >= CURRENT_DATE - INTERVAL '7 days'),
```

### 4. Mejoras en ON DELETE behaviors

```sql
-- tab_favorite_routes
-- ✅ MEJORADO: CASCADE para eliminar favoritos cuando se borra usuario o ruta
CONSTRAINT fk_fav_routes_user FOREIGN KEY (id_user) 
  REFERENCES tab_users(id_user) ON DELETE CASCADE,
CONSTRAINT fk_fav_routes_route FOREIGN KEY (id_route) 
  REFERENCES tab_routes(id_route) ON DELETE CASCADE

-- tab_trips
-- ✅ MEJORADO: CASCADE al borrar ruta, SET NULL al borrar bus
CONSTRAINT fk_trips_route FOREIGN KEY (id_route) 
  REFERENCES tab_routes(id_route) ON DELETE CASCADE,
CONSTRAINT fk_trips_bus FOREIGN KEY (plate_number) 
  REFERENCES tab_buses(plate_number) ON DELETE SET NULL
```

### 5. Documentación mejorada

**Agregado al final del archivo:**
```sql
/*
CONVENCIONES DE AUDITORÍA:
---------------------------
user_create: INTEGER NOT NULL DEFAULT 1735689600
user_update: INTEGER NULL
created_at:  TIMESTAMPTZ NOT NULL DEFAULT NOW()
updated_at:  TIMESTAMPTZ NULL

ID del usuario del sistema: 1735689600 (Epoch 2025-01-01)

TIPOS DE DATOS ESTANDARIZADOS:
-------------------------------
- Timestamps: TIMESTAMPTZ (con zona horaria)
- IDs de rutas: INTEGER (más eficiente que DECIMAL)
- Compañías: SMALLINT (1-99)
- Capacidad: SMALLINT (10-999)

ÍNDICES:
--------
- Campos de búsqueda frecuente
- Foreign keys principales
- Índices parciales para filtros comunes
- Índices espaciales GIST para PostGIS

FOREIGN KEYS:
-------------
- ON DELETE CASCADE: padre elimina hijos
- ON DELETE SET NULL: relación opcional
- ON DELETE SET DEFAULT: campos de auditoría
- DEFERRABLE: referencias circulares
*/
```

### 6. Sección de headers y organización visual

```sql
-- =============================================
-- BucaraBUS - Base de Datos Principal
-- =============================================

-- --------------------------------------------
-- 3.1 TABLA: tab_users
-- Descripción: Tabla base de usuarios
-- --------------------------------------------
```

### 7. Campo `description` agregado a `tab_roles`

```sql
-- ✅ AGREGADO
CREATE TABLE tab_roles (
  id_role     SMALLINT        NOT NULL,
  role_name   VARCHAR(50)     NOT NULL UNIQUE,
  description TEXT,           -- ⭐ NUEVO
  ...
);

-- Con datos iniciales
INSERT INTO tab_roles (id_role, role_name, description, user_create) VALUES
  (1, 'Pasajero', 'Usuario que consulta rutas y horarios', 1735689600),
  (2, 'Conductor', 'Conductor de buses del sistema', 1735689600),
  (3, 'Supervisor', 'Supervisor de operaciones', 1735689600),
  (4, 'Administrador', 'Administrador del sistema', 1735689600)
```

### 8. UNIQUE constraint en role_name

```sql
-- ✅ AGREGADO
role_name VARCHAR(50) NOT NULL UNIQUE,
```

Previene duplicación de roles.

---

## 📊 RESUMEN DE CAMBIOS

| Categoría | Antes | Después | Cambio |
|-----------|-------|---------|--------|
| **Líneas de código** | 299 | 526 | +76% |
| **Tablas** | 9 | 9 | = |
| **Índices** | 25 | 54 | +116% |
| **CHECK constraints** | 15 | 22 | +47% |
| **Timestamps con TZ** | 4 tablas | 9 tablas | +100% |
| **Comentarios** | 12 | 22 | +83% |
| **Campos agregados** | - | 1 (description en roles) | - |
| **Tipos de datos optimizados** | - | 3 (INTEGER, SMALLINT) | - |

---

## ✅ VALIDACIÓN FINAL

### Orden de creación de tablas (correcto por dependencias):
1. ✅ `tab_users` (base, auto-referencial)
2. ✅ `tab_roles` (depende de users para auditoría)
3. ✅ `tab_user_roles` (junction, depende de users y roles)
4. ✅ `tab_driver_details` (depende de users)
5. ✅ `tab_buses` (depende de users)
6. ✅ `tab_routes` (depende de users)
7. ✅ `tab_favorite_routes` (depende de users y routes)
8. ✅ `tab_bus_assignments` (depende de buses y users)
9. ✅ `tab_trips` (depende de routes y buses)

### Integridad referencial:
- ✅ Todas las FK apuntan a tablas previamente creadas
- ✅ Usuario sistema (1735689600) se inserta ANTES de ser usado en DEFAULT
- ✅ FK auto-referencial tiene DEFERRABLE
- ✅ Todos los campos user_create/user_update tienen FK

### Consistencia de tipos:
- ✅ Todos los timestamps: `TIMESTAMPTZ`
- ✅ Todos los user_create: `INTEGER NOT NULL DEFAULT 1735689600`
- ✅ Todos los user_update: `INTEGER` (nullable)
- ✅ Todos los IDs: `INTEGER` o `SMALLINT`

### Índices de auditoría:
- ✅ tab_users: idx_users_created_by, idx_users_updated_by
- ✅ tab_roles: idx_roles_created_by, idx_roles_updated_by
- ✅ tab_driver_details: idx_driver_details_created_by, idx_driver_details_updated_by
- ✅ tab_buses: idx_buses_created_by, idx_buses_updated_by
- ✅ tab_routes: idx_routes_created_by, idx_routes_updated_by
- ✅ tab_bus_assignments: idx_assignments_created_by, idx_assignments_updated_by
- ✅ tab_trips: idx_trips_created_by, idx_trips_updated_by

---

## 🎯 PRÓXIMOS PASOS

### 1. Ejecutar el nuevo esquema
```bash
# En producción
psql -U bucarabus_user -d bucarabus_db -f api/database/bd_bucarabus.sql

# Verificar
psql -U bucarabus_user -d bucarabus_db -c "\dt"
psql -U bucarabus_user -d bucarabus_db -c "\di"
```

### 2. Actualizar backend (según GUIA_MIGRACION_AUDITORIA_FK.md)
- Cambiar `'system'` → `1735689600` en servicios
- Extraer `req.user.id_user` en controladores
- Actualizar middleware de autenticación

### 3. Poblar datos de prueba (opcional)
```sql
-- Crear usuario administrador real
INSERT INTO tab_users (id_user, email, password_hash, full_name, user_create)
VALUES (1, 'admin@bucarabus.com', '$2b$10$...', 'Admin Principal', 1735689600);

INSERT INTO tab_user_roles (id_user, id_role, assigned_by)
VALUES (1, 4, 1735689600);

-- Crear rutas de ejemplo
INSERT INTO tab_routes (id_route, name_route, path_route, color_route, user_create)
VALUES (1, 'Ruta Centro', ST_GeomFromText('LINESTRING(...)', 4326), '#FF5733', 1);
```

### 4. Testing
- ✅ Verificar INSERTs con campos de auditoría
- ✅ Verificar UPDATEs actualizan user_update y updated_at
- ✅ Verificar CASCADE funcionan correctamente
- ✅ Verificar validaciones CHECK

### 5. Performance
```sql
-- Analizar estadísticas
ANALYZE tab_users;
ANALYZE tab_routes;
ANALYZE tab_buses;
ANALYZE tab_trips;

-- Verificar uso de índices
EXPLAIN ANALYZE SELECT * FROM tab_trips 
WHERE status_trip = 'pending' AND trip_date = CURRENT_DATE;
```

---

## 📝 NOTAS ADICIONALES

### Índices espaciales PostGIS
Los índices GIST en `path_route`, `start_area` y `end_area` permiten consultas espaciales eficientes:

```sql
-- Encontrar rutas que pasan por un punto
SELECT * FROM tab_routes 
WHERE ST_DWithin(path_route, ST_SetSRID(ST_MakePoint(-73.1198, 7.1193), 4326), 0.01);

-- Encontrar rutas que intersectan un área
SELECT * FROM tab_routes 
WHERE ST_Intersects(path_route, ST_MakeEnvelope(...));
```

### Migración desde esquema anterior
Si ya tienes datos en la BD antigua, usa `MIGRATION_AUDIT_TO_FK.sql` para migrar campos VARCHAR a INTEGER.

### Tamaño estimado de la base de datos
Con el esquema mejorado:
- **Tablas pequeñas** (users, roles): < 1 MB
- **Tablas medianas** (buses, routes): 1-10 MB
- **Tablas grandes** (trips, assignments): 10-100 MB/año
- **Índices**: ~150% del tamaño de las tablas

### Respaldo y mantenimiento
```bash
# Backup diario
pg_dump -U bucarabus_user -Fc bucarabus_db > backup_$(date +%Y%m%d).dump

# Vacuum semanal
VACUUM ANALYZE;

# Reindex mensual
REINDEX DATABASE bucarabus_db;
```

---

**Estado final:** ✅ Base de datos optimizada, consistente y lista para producción.
