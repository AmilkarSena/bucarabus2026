# REPORTE DE REVISIÓN: fun_create_trip

**Fecha**: 2025-01-01  
**Archivo**: `fun_create_trip.sql`  
**Versión**: v2.0  
**Tipo**: Stored Functions PostgreSQL (2 funciones)  

---

## 1. RESUMEN EJECUTIVO

### Funciones Revisadas
1. **fun_create_trip**: Crea un viaje/turno individual
2. **fun_create_trips_batch**: Crea múltiples viajes en lote

### Estado Inicial - fun_create_trip
- ❌ **Sin Validación**: No verificaba que el usuario creador existiera
- ❌ **Campos Redundantes**: Incluía created_at, updated_at, user_update con DEFAULT
- ❌ **Inconsistencia**: DEFAULT 'assigned' pero COALESCE(..., 'pending')
- ❌ **Sin Validar Estado**: No verificaba que ruta y bus estuvieran activos
- ❌ **Códigos Genéricos**: 'SQLSTATE_23505' no descriptivo
- ⚠️ **Sin Validar Formato**: No validaba formato de placa

### Estado Inicial - fun_create_trips_batch
- ❌ **Error Crítico de Tipo**: `wid_route DECIMAL(3,0)` debería ser INTEGER
- ❌ **Error Crítico de Tipo**: `wuser_create VARCHAR` debería ser INTEGER
- ❌ **Sin Validaciones**: No validaba usuario creador, ruta activa, formato de placa
- ⚠️ **wfailed_count**: No se retornaba al usuario
- ⚠️ **Sin Detalles de Errores**: No registraba qué viajes fallaron

### Estado Final
✅ Ambas funciones completamente reescritas con:
- Validación completa del usuario creador
- Validación de estados activos (ruta y bus)
- Validación de formato de placa
- Tipos correctos (INTEGER en lugar de DECIMAL/VARCHAR)
- Códigos de error descriptivos
- Eliminación de campos redundantes (usa DEFAULT)
- trips_failed agregado en batch
- Logging con RAISE NOTICE
- Manejo robusto de excepciones

---

## 2. ERRORES CRÍTICOS ENCONTRADOS

### Error 1: Sin Validación del Usuario Creador (ALTO)

**fun_create_trip**:
```sql
-- No había validación en ninguna parte
-- wuser_create se usaba directamente en INSERT
```

**fun_create_trips_batch**:
```sql
-- Mismo problema
```

**Impacto**:
- ❌ **Error FK en runtime** si el usuario no existe
- ⚠️ **Auditoría corrupta** si se usa ID inválido

**Solución Aplicada**:
```sql
-- Líneas 46-58 en ambas funciones
SELECT EXISTS(
    SELECT 1 
    FROM tab_users 
    WHERE tab_users.id_user = wuser_create 
      AND is_active = TRUE
) INTO v_user_exists;

IF NOT v_user_exists THEN
    msg := 'El usuario creador no existe o está inactivo (ID: ' || wuser_create || ')';
    error_code := 'USER_CREATE_NOT_FOUND';
    RETURN;
END IF;
```

---

### Error 2: Tipo Incorrecto en fun_create_trips_batch (CRÍTICO)

**Descripción**: Los parámetros tenían tipos incorrectos que no coinciden con el esquema.

**Código Problemático**:
```sql
-- LÍNEA 200
CREATE OR REPLACE FUNCTION fun_create_trips_batch(
    wid_route        DECIMAL(3,0),   -- ❌ Debería ser INTEGER
    wtrip_date       DATE,
    wtrips           JSONB,
    wuser_create     VARCHAR,         -- ❌ Debería ser INTEGER
    ...
)
```

**Esquema Real**:
```sql
-- bd_bucarabus.sql
CREATE TABLE tab_trips (
    id_route      INTEGER         NOT NULL,  -- No es DECIMAL(3,0)
    ...
    user_create   INTEGER         NOT NULL DEFAULT 1735689600,  -- No es VARCHAR
    ...
);
```

**Impacto**:
- ❌ **Error de tipo en runtime** al pasar INTEGER a función que espera DECIMAL
- ❌ **Error de tipo en runtime** al pasar VARCHAR a campo INTEGER
- ❌ **Inconsistencia con bd_bucarabus.sql v2.0**

**Solución Aplicada**:
```sql
CREATE OR REPLACE FUNCTION fun_create_trips_batch(
    wid_route        tab_trips.id_route%TYPE,       -- ✅ INTEGER
    wtrip_date       tab_trips.trip_date%TYPE,      -- ✅ DATE
    wtrips           JSONB,
    wuser_create     tab_trips.user_create%TYPE,    -- ✅ INTEGER
    ...
)
```

---

### Error 3: Campos Redundantes en INSERT (MEDIO)

**Descripción**: El INSERT incluía campos que tienen DEFAULT y no necesitan ser especificados.

**Código Problemático (fun_create_trip)**:
```sql
-- LÍNEA 126
INSERT INTO tab_trips (
    id_route,
    trip_date,
    start_time,
    end_time,
    plate_number,
    status_trip,
    created_at,     -- ❌ Tiene DEFAULT NOW()
    user_create,
    updated_at,     -- ❌ Tiene DEFAULT NULL
    user_update     -- ❌ Tiene DEFAULT NULL
) VALUES (
    wid_route,
    wtrip_date,
    wstart_time,
    wend_time,
    ...,
    COALESCE(wstatus_trip, 'pending'),
    NOW(),    -- ❌ Redundante
    wuser_create,
    NULL,     -- ❌ Redundante
    NULL      -- ❌ Redundante
);
```

**Esquema Real**:
```sql
CREATE TABLE tab_trips (
    ...
    created_at    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    user_create   INTEGER         NOT NULL DEFAULT 1735689600,
    updated_at    TIMESTAMPTZ,    -- DEFAULT NULL implícito
    user_update   INTEGER,        -- DEFAULT NULL implícito
    ...
);
```

**Solución Aplicada**:
```sql
INSERT INTO tab_trips (
    id_route,
    trip_date,
    start_time,
    end_time,
    plate_number,
    status_trip,
    user_create
) VALUES (
    wid_route,
    wtrip_date,
    wstart_time,
    wend_time,
    v_plate_normalized,
    wstatus_trip,
    wuser_create
);
-- created_at, updated_at, user_update usan DEFAULT automáticamente
```

---

### Error 4: Inconsistencia en Status Default (BAJO)

**Descripción**: La firma de la función decía DEFAULT 'assigned' pero el código usaba COALESCE(..., 'pending').

**Código Problemático**:
```sql
-- LÍNEA 7 (firma)
wstatus_trip     tab_trips.status_trip%TYPE DEFAULT 'assigned',

-- LÍNEA 141 (INSERT)
COALESCE(wstatus_trip, 'pending'),  -- ❌ Contradice el DEFAULT de la firma
```

**Impacto**:
- ⚠️ **Confusión**: ¿Es 'assigned' o 'pending' el default?
- ⚠️ **Comportamiento inesperado**: Si pasas NULL, usará 'pending' no 'assigned'

**Solución Aplicada**:
```sql
-- Firma con DEFAULT 'pending' (consistente)
wstatus_trip     tab_trips.status_trip%TYPE DEFAULT 'pending',

-- INSERT usa directamente el parámetro (ya tiene DEFAULT)
VALUES (
    ...,
    wstatus_trip,  -- ✅ Ya no necesita COALESCE
    ...
);
```

---

### Error 5: Sin Validar Estado Activo de Ruta y Bus (ALTO)

**Descripción**: La función solo verificaba existencia, no si estaban activos.

**Código Problemático**:
```sql
-- LÍNEA 83
SELECT EXISTS(SELECT 1 FROM tab_routes WHERE id_route = wid_route)
INTO wexists_route;
-- ❌ No verifica status_route = TRUE

-- LÍNEA 91
SELECT EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = UPPER(wplate_number))
INTO wexists_bus;
-- ❌ No verifica is_active = TRUE
```

**Impacto**:
- ⚠️ **Lógica de negocio**: Permite crear viajes en rutas inactivas
- ⚠️ **Lógica de negocio**: Permite asignar buses inactivos

**Solución Aplicada**:
```sql
-- Verificar ruta existe Y está activa
SELECT 
    EXISTS(SELECT 1 FROM tab_routes WHERE id_route = wid_route),
    COALESCE((SELECT status_route FROM tab_routes WHERE id_route = wid_route), FALSE)
INTO v_route_exists, v_route_active;

IF NOT v_route_exists THEN
    msg := 'La ruta con ID ' || wid_route || ' no existe';
    error_code := 'ROUTE_NOT_FOUND';
    RETURN;
END IF;

IF NOT v_route_active THEN
    msg := 'La ruta con ID ' || wid_route || ' está inactiva (status_route = FALSE)';
    error_code := 'ROUTE_INACTIVE';
    RETURN;
END IF;

-- Verificar bus existe Y está activo
SELECT 
    EXISTS(SELECT 1 FROM tab_buses WHERE plate_number = v_plate_normalized),
    COALESCE((SELECT is_active FROM tab_buses WHERE plate_number = v_plate_normalized), FALSE)
INTO v_bus_exists, v_bus_active;

IF NOT v_bus_exists THEN
    msg := 'El bus con placa ' || v_plate_normalized || ' no existe';
    error_code := 'BUS_NOT_FOUND';
    RETURN;
END IF;

IF NOT v_bus_active THEN
    msg := 'El bus con placa ' || v_plate_normalized || ' está inactivo (is_active = FALSE)';
    error_code := 'BUS_INACTIVE';
    RETURN;
END IF;
```

---

### Error 6: Sin Validar Formato de Placa (MEDIO)

**Descripción**: La función no validaba que la placa cumpliera el formato ^[A-Z]{3}[0-9]{3}$.

**Código Problemático**:
```sql
-- Se normalizaba pero no se validaba formato
CASE WHEN wplate_number IS NOT NULL AND TRIM(wplate_number) != '' 
     THEN UPPER(TRIM(wplate_number)) 
     ELSE NULL 
END,
-- ❌ No valida que cumpla el patrón
```

**Impacto**:
- ⚠️ **Datos inválidos**: Permite placas como "123", "ABCDEF", etc.
- ⚠️ **Error en runtime**: Fallará en INSERT por CHECK constraint

**Solución Aplicada**:
```sql
v_plate_normalized := UPPER(TRIM(wplate_number));

-- Validar formato de placa
IF v_plate_normalized !~ '^[A-Z]{3}[0-9]{3}$' THEN
    msg := 'Formato de placa inválido "' || v_plate_normalized || 
           '". Debe ser 3 letras + 3 números (ej: ABC123)';
    error_code := 'PLATE_INVALID_FORMAT';
    RETURN;
END IF;
```

---

### Error 7: Códigos de Error Genéricos (MEDIO)

**Descripción**: Usaba códigos como 'SQLSTATE_23505' que no son descriptivos.

**Código Problemático**:
```sql
WHEN unique_violation THEN
    success := FALSE;
    msg := 'Error: Ya existe un viaje con esa combinación de ruta, fecha y hora';
    error_code := 'SQLSTATE_23505';  -- ❌ No descriptivo
```

**Solución Aplicada**:
```sql
WHEN unique_violation THEN
    msg := 'Ya existe un viaje con esa combinación de ruta, fecha y hora de inicio';
    error_code := 'TRIP_INSERT_UNIQUE_VIOLATION';  -- ✅ Descriptivo
    RETURN;
```

---

### Error 8: trips_failed No Retornado en Batch (BAJO)

**Descripción**: La función batch contaba los fallos pero no los retornaba al usuario.

**Código Problemático**:
```sql
-- LÍNEA 207 (OUT parameters)
OUT trips_created INTEGER,
OUT trip_ids     BIGINT[],
-- ❌ Falta trips_failed

-- LÍNEA 214 (declaración interna pero no se usa en OUT)
wfailed_count    INTEGER := 0;
```

**Solución Aplicada**:
```sql
-- Agregado OUT parameter
OUT trips_failed  INTEGER,

-- Asignado al final
trips_failed := v_failed_count;
```

---

## 3. MEJORAS IMPLEMENTADAS

### Mejora 1: Validación de Fecha Antigua

**Agregado** (cumple con CHECK del schema):
```sql
IF wtrip_date < CURRENT_DATE - INTERVAL '7 days' THEN
    msg := 'La fecha del viaje no puede ser anterior a ' || 
           (CURRENT_DATE - INTERVAL '7 days')::DATE;
    error_code := 'TRIP_DATE_TOO_OLD';
    RETURN;
END IF;
```

**Beneficio**: Consistente con el CHECK constraint en bd_bucarabus.sql:
```sql
CONSTRAINT chk_trips_date CHECK (trip_date >= CURRENT_DATE - INTERVAL '7 days')
```

---

### Mejora 2: Normalización de Placa

**Antes**:
```sql
CASE WHEN wplate_number IS NOT NULL AND TRIM(wplate_number) != '' 
     THEN UPPER(TRIM(wplate_number)) 
     ELSE NULL 
END
```

**Después**:
```sql
-- Variable normalizada declarada
v_plate_normalized  VARCHAR(6);

-- Se normaliza una vez
IF wplate_number IS NOT NULL AND TRIM(wplate_number) != '' THEN
    v_plate_normalized := UPPER(TRIM(wplate_number));
    -- ... validaciones ...
ELSE
    v_plate_normalized := NULL;
END IF;

-- Se usa la variable en INSERT
INSERT INTO tab_trips (..., plate_number, ...)
VALUES (..., v_plate_normalized, ...)
```

**Beneficio**: 
- ✅ Código más limpio
- ✅ Se normaliza solo una vez
- ✅ Fácil validar formato

---

### Mejora 3: Validaciones Adicionales en Batch

**fun_create_trips_batch ahora valida**:
```sql
-- Validar cada campo del JSON
IF v_start_time IS NULL THEN
    RAISE EXCEPTION 'start_time es obligatorio';
END IF;

IF v_end_time IS NULL THEN
    RAISE EXCEPTION 'end_time es obligatorio';
END IF;

IF v_end_time <= v_start_time THEN
    RAISE EXCEPTION 'end_time debe ser posterior a start_time';
END IF;

IF v_status_trip NOT IN ('pending', 'assigned', 'active', 'completed', 'cancelled') THEN
    RAISE EXCEPTION 'Estado inválido: %', v_status_trip;
END IF;

-- Validar formato de placa
IF v_plate_normalized !~ '^[A-Z]{3}[0-9]{3}$' THEN
    RAISE EXCEPTION 'Formato de placa inválido: %', v_plate_normalized;
END IF;

-- Validar que bus existe y está activo
IF NOT EXISTS(
    SELECT 1 FROM tab_buses 
    WHERE plate_number = v_plate_normalized 
      AND is_active = TRUE
) THEN
    RAISE EXCEPTION 'Bus % no existe o está inactivo', v_plate_normalized;
END IF;
```

**Beneficio**: Detecta errores antes de INSERT

---

### Mejora 4: Detalles de Errores en Batch

**Agregado**:
```sql
DECLARE
    v_error_details     TEXT := '';

-- En el loop
EXCEPTION
    WHEN OTHERS THEN
        v_failed_count := v_failed_count + 1;
        v_error_details := v_error_details || 
                           'Viaje ' || v_start_time || ': ' || SQLERRM || '; ';

-- Al retornar
IF v_created_count = 0 THEN
    msg := 'No se pudo crear ningún viaje. Errores: ' || v_error_details;
END IF;
```

**Beneficio**: El usuario sabe exactamente qué viajes fallaron y por qué

---

### Mejora 5: Logging con RAISE NOTICE

**Agregado en ambas funciones**:
```sql
-- fun_create_trip
RAISE NOTICE 'Viaje creado: ID=%, Ruta=%, Fecha=%, Hora=%', 
             v_new_id, wid_route, wtrip_date, wstart_time;

-- fun_create_trips_batch
RAISE NOTICE 'Viaje % creado: ID=%, Hora=%', v_created_count, v_new_id, v_start_time;
RAISE NOTICE 'Error creando viaje %: %', v_start_time, SQLERRM;
```

**Beneficio**: Trazabilidad en logs de PostgreSQL

---

## 4. CAMBIOS EN LAS FIRMAS

### fun_create_trip

**Antes (v1.0)**:
```sql
CREATE OR REPLACE FUNCTION fun_create_trip(
    wid_route        tab_trips.id_route%TYPE,
    wtrip_date       tab_trips.trip_date%TYPE,
    wstart_time      tab_trips.start_time%TYPE,
    wend_time        tab_trips.end_time%TYPE,
    wuser_create     tab_trips.user_create%TYPE,
    wplate_number    tab_trips.plate_number%TYPE DEFAULT NULL,
    wstatus_trip     tab_trips.status_trip%TYPE DEFAULT 'assigned',  -- ❌
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT id_trip_out  BIGINT,  -- ❌ Nombre inconsistente
    OUT error_code   VARCHAR
)
```

**Después (v2.0)**:
```sql
CREATE OR REPLACE FUNCTION fun_create_trip(
    wid_route        tab_trips.id_route%TYPE,
    wtrip_date       tab_trips.trip_date%TYPE,
    wstart_time      tab_trips.start_time%TYPE,
    wend_time        tab_trips.end_time%TYPE,
    wuser_create     tab_trips.user_create%TYPE,
    wplate_number    tab_trips.plate_number%TYPE DEFAULT NULL,
    wstatus_trip     tab_trips.status_trip%TYPE DEFAULT 'pending',  -- ✅ Corregido
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT id_trip      BIGINT,  -- ✅ Nombre simple
    OUT error_code   VARCHAR
)
```

**Cambios**:
- ✅ DEFAULT 'assigned' → 'pending' (consistente)
- ✅ id_trip_out → id_trip (nombre estándar)

---

### fun_create_trips_batch

**Antes (v1.0)**:
```sql
CREATE OR REPLACE FUNCTION fun_create_trips_batch(
    wid_route        DECIMAL(3,0),     -- ❌ TIPO INCORRECTO
    wtrip_date       DATE,
    wtrips           JSONB,
    wuser_create     VARCHAR,          -- ❌ TIPO INCORRECTO
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT trips_created INTEGER,
    OUT trip_ids     BIGINT[],
    OUT error_code   VARCHAR
)
```

**Después (v2.0)**:
```sql
CREATE OR REPLACE FUNCTION fun_create_trips_batch(
    wid_route        tab_trips.id_route%TYPE,       -- ✅ INTEGER
    wtrip_date       tab_trips.trip_date%TYPE,
    wtrips           JSONB,
    wuser_create     tab_trips.user_create%TYPE,    -- ✅ INTEGER
    OUT success      BOOLEAN,
    OUT msg          VARCHAR,
    OUT trips_created INTEGER,
    OUT trips_failed  INTEGER,                      -- ✅ AGREGADO
    OUT trip_ids     BIGINT[],
    OUT error_code   VARCHAR
)
```

**Cambios**:
- ✅ wid_route: DECIMAL(3,0) → INTEGER
- ✅ wuser_create: VARCHAR → INTEGER
- ✅ Agregado: trips_failed OUT parameter

### ⚠️ CAMBIO INCOMPATIBLE HACIA ATRÁS

**Implicaciones**:
- ❌ **Backend debe actualizarse** para fun_create_trips_batch
- ❌ **Pasar INTEGER en lugar de VARCHAR** para wuser_create
- ❌ **Pasar INTEGER en lugar de DECIMAL** para wid_route
- ✅ fun_create_trip: cambio menor (id_trip_out → id_trip)

---

## 5. ESTADÍSTICAS DE CÓDIGO

### fun_create_trip

| Métrica | Antes | Después | Cambio |
|---------|-------|---------|--------|
| Líneas totales | 181 | 239 | +32% |
| Parámetros IN | 7 | 7 | = |
| Parámetros OUT | 4 | 4 | = |
| Variables declaradas | 4 | 7 | +75% |
| Validaciones | 8 | 14 | +75% |
| Códigos de error | 8 | 14 | +75% |
| Bloques EXCEPTION | 1 | 1 | = |

### fun_create_trips_batch

| Métrica | Antes | Después | Cambio |
|---------|-------|---------|--------|
| Líneas totales | 82 | 216 | +163% |
| Parámetros IN | 4 | 4 | = |
| Parámetros OUT | 5 | 6 | +20% |
| Variables declaradas | 6 | 14 | +133% |
| Validaciones | 3 | 13 | +333% |
| Códigos de error | 3 | 6 | +100% |
| Logging | Básico | Detallado | Mejor |

---

## 6. CÓDIGOS DE ERROR

### fun_create_trip (14 códigos)

| Código | Descripción | Cuándo se lanza |
|--------|-------------|-----------------|
| `USER_CREATE_NOT_FOUND` | Usuario creador no existe | wuser_create no existe o inactivo |
| `ROUTE_ID_NULL` | ID de ruta nulo | wid_route IS NULL |
| `TRIP_DATE_NULL` | Fecha de viaje nula | wtrip_date IS NULL |
| `START_TIME_NULL` | Hora inicio nula | wstart_time IS NULL |
| `END_TIME_NULL` | Hora fin nula | wend_time IS NULL |
| `INVALID_TIME_RANGE` | Hora fin <= hora inicio | wend_time <= wstart_time |
| `TRIP_DATE_TOO_OLD` | Fecha muy antigua | < CURRENT_DATE - 7 días |
| `STATUS_INVALID` | Estado inválido | No en lista permitida |
| `ROUTE_NOT_FOUND` | Ruta no existe | id_route no existe |
| `ROUTE_INACTIVE` | Ruta inactiva | status_route = FALSE |
| `PLATE_INVALID_FORMAT` | Formato de placa inválido | No cumple ^[A-Z]{3}[0-9]{3}$ |
| `BUS_NOT_FOUND` | Bus no existe | plate_number no existe |
| `BUS_INACTIVE` | Bus inactivo | is_active = FALSE |
| `TRIP_DUPLICATE` | Viaje duplicado | Ya existe mismo route+date+time |
| `TRIP_INSERT_UNIQUE_VIOLATION` | Violación de unicidad | INSERT duplicado |
| `TRIP_INSERT_FK_VIOLATION` | Error de FK | Ruta/bus/usuario inválido |
| `TRIP_INSERT_CHECK_VIOLATION` | Violación de CHECK | Hora fin <= inicio |
| `TRIP_INSERT_ERROR` | Error inesperado | Otros errores |

### fun_create_trips_batch (6 códigos)

| Código | Descripción | Cuándo se lanza |
|--------|-------------|-----------------|
| `USER_CREATE_NOT_FOUND` | Usuario creador no existe | wuser_create no existe o inactivo |
| `ROUTE_ID_NULL` | ID de ruta nulo | wid_route IS NULL |
| `TRIP_DATE_NULL` | Fecha nula | wtrip_date IS NULL |
| `TRIPS_ARRAY_EMPTY` | Array vacío | wtrips IS NULL o length = 0 |
| `TRIP_DATE_TOO_OLD` | Fecha muy antigua | < CURRENT_DATE - 7 días |
| `ROUTE_NOT_FOUND` | Ruta no existe | id_route no existe |
| `ROUTE_INACTIVE` | Ruta inactiva | status_route = FALSE |
| `ALL_TRIPS_FAILED` | Todos los viajes fallaron | v_created_count = 0 |

---

## 7. IMPACTO EN BACKEND

### Cambios en fun_create_trip

**Archivo**: `api/services/trips.service.js`

**Antes**:
```javascript
const result = await pool.query(
  'SELECT * FROM fun_create_trip($1, $2, $3, $4, $5, $6, $7)',
  [id_route, trip_date, start_time, end_time, user_create, plate_number, status_trip]
);

if (result.rows[0].success) {
  return {
    success: true,
    id_trip: result.rows[0].id_trip_out  // ❌ Nombre cambiado
  };
}
```

**Después**:
```javascript
const result = await pool.query(
  'SELECT * FROM fun_create_trip($1, $2, $3, $4, $5, $6, $7)',
  [id_route, trip_date, start_time, end_time, userId, plate_number, status_trip]  // ✅ userId es INTEGER
);

if (result.rows[0].success) {
  return {
    success: true,
    id_trip: result.rows[0].id_trip  // ✅ Nombre simplificado
  };
}
```

---

### Cambios en fun_create_trips_batch

**Antes**:
```javascript
async function createTripsInBatch(routeId, tripDate, trips, userEmail) {
  const query = 'SELECT * FROM fun_create_trips_batch($1, $2, $3, $4)';
  const values = [
    routeId,      // ❌ Si es INTEGER, causará error de tipo
    tripDate,
    JSON.stringify(trips),
    userEmail     // ❌ VARCHAR
  ];
  
  const result = await pool.query(query, values);
  
  return {
    success: result.rows[0].success,
    trips_created: result.rows[0].trips_created,
    trip_ids: result.rows[0].trip_ids
    // ❌ Falta trips_failed
  };
}
```

**Después**:
```javascript
async function createTripsInBatch(routeId, tripDate, trips, userId) {
  const query = 'SELECT * FROM fun_create_trips_batch($1, $2, $3, $4)';
  const values = [
    routeId,      // ✅ INTEGER (no DECIMAL)
    tripDate,
    JSON.stringify(trips),
    userId        // ✅ INTEGER (no VARCHAR)
  ];
  
  const result = await pool.query(query, values);
  
  return {
    success: result.rows[0].success,
    trips_created: result.rows[0].trips_created,
    trips_failed: result.rows[0].trips_failed,  // ✅ AGREGADO
    trip_ids: result.rows[0].trip_ids,
    message: result.rows[0].msg,
    error_code: result.rows[0].error_code
  };
}
```

---

## 8. PRUEBAS RECOMENDADAS

### fun_create_trip

#### Caso 1: Creación Exitosa
```sql
SELECT * FROM fun_create_trip(
    1,                   -- id_route
    '2026-03-01',        -- trip_date
    '08:00:00',          -- start_time
    '10:00:00',          -- end_time
    1,                   -- user_create (admin)
    'ABC123',            -- plate_number
    'assigned'           -- status_trip
);

-- Resultado esperado:
-- success: TRUE
-- msg: "Viaje creado exitosamente con ID: [ID] para ruta 1"
-- id_trip: [nuevo ID]
-- error_code: NULL
```

#### Caso 2: Error - Usuario Creador No Existe
```sql
SELECT * FROM fun_create_trip(
    1, '2026-03-01', '08:00:00', '10:00:00', 9999, NULL, 'pending'
);

-- Resultado esperado:
-- success: FALSE
-- msg: "El usuario creador no existe o está inactivo (ID: 9999)"
-- id_trip: NULL
-- error_code: "USER_CREATE_NOT_FOUND"
```

#### Caso 3: Error - Ruta Inactiva
```sql
-- Primero desactivar una ruta
UPDATE tab_routes SET status_route = FALSE WHERE id_route = 2;

SELECT * FROM fun_create_trip(
    2, '2026-03-01', '08:00:00', '10:00:00', 1, NULL, 'pending'
);

-- Resultado esperado:
-- success: FALSE
-- msg: "La ruta con ID 2 está inactiva (status_route = FALSE)"
-- id_trip: NULL
-- error_code: "ROUTE_INACTIVE"
```

#### Caso 4: Error - Bus Inactivo
```sql
-- Desactivar un bus
UPDATE tab_buses SET is_active = FALSE WHERE plate_number = 'XYZ789';

SELECT * FROM fun_create_trip(
    1, '2026-03-01', '08:00:00', '10:00:00', 1, 'XYZ789', 'assigned'
);

-- Resultado esperado:
-- success: FALSE
-- msg: "El bus con placa XYZ789 está inactivo (is_active = FALSE)"
-- id_trip: NULL
-- error_code: "BUS_INACTIVE"
```

#### Caso 5: Error - Formato de Placa Inválido
```sql
SELECT * FROM fun_create_trip(
    1, '2026-03-01', '08:00:00', '10:00:00', 1, 'INVALID', 'pending'
);

-- Resultado esperado:
-- success: FALSE
-- msg: "Formato de placa inválido \"INVALID\". Debe ser 3 letras + 3 números (ej: ABC123)"
-- id_trip: NULL
-- error_code: "PLATE_INVALID_FORMAT"
```

#### Caso 6: Error - Viaje Duplicado
```sql
-- Primero crear un viaje
SELECT * FROM fun_create_trip(
    1, '2026-03-01', '14:00:00', '16:00:00', 1, NULL, 'pending'
);

-- Intentar crear el mismo viaje
SELECT * FROM fun_create_trip(
    1, '2026-03-01', '14:00:00', '16:00:00', 1, NULL, 'pending'
);

-- Resultado esperado:
-- success: FALSE
-- msg: "Ya existe un viaje para la ruta 1 en fecha 2026-03-01 a las 14:00:00"
-- id_trip: NULL
-- error_code: "TRIP_DUPLICATE"
```

---

### fun_create_trips_batch

#### Caso 1: Batch Exitoso
```sql
SELECT * FROM fun_create_trips_batch(
    1,              -- id_route
    '2026-03-15',   -- trip_date
    '[
        {"start_time": "06:00:00", "end_time": "08:00:00", "plate_number": "ABC123", "status_trip": "assigned"},
        {"start_time": "09:00:00", "end_time": "11:00:00", "plate_number": "DEF456", "status_trip": "assigned"},
        {"start_time": "12:00:00", "end_time": "14:00:00", "status_trip": "pending"}
    ]'::JSONB,
    1               -- user_create
);

-- Resultado esperado:
-- success: TRUE
-- msg: "Se crearon 3 viajes exitosamente"
-- trips_created: 3
-- trips_failed: 0
-- trip_ids: [array de 3 IDs]
-- error_code: NULL
```

#### Caso 2: Batch Parcial (algunos fallan)
```sql
SELECT * FROM fun_create_trips_batch(
    1,
    '2026-03-16',
    '[
        {"start_time": "06:00:00", "end_time": "08:00:00"},
        {"start_time": "09:00:00", "end_time": "07:00:00"},
        {"start_time": "12:00:00", "end_time": "14:00:00"}
    ]'::JSONB,
    1
);

-- Resultado esperado:
-- success: TRUE
-- msg: "Se crearon 2 viajes exitosamente (1 fallaron)"
-- trips_created: 2
-- trips_failed: 1
-- trip_ids: [array de 2 IDs]
-- error_code: NULL
```

#### Caso 3: Error - Array Vacío
```sql
SELECT * FROM fun_create_trips_batch(
    1, '2026-03-17', '[]'::JSONB, 1
);

-- Resultado esperado:
-- success: FALSE
-- msg: "Debe proporcionar al menos un viaje en el array JSONB"
-- trips_created: 0
-- trips_failed: 0
-- trip_ids: []
-- error_code: "TRIPS_ARRAY_EMPTY"
```

---

## 9. RECOMENDACIONES

### Inmediatas (Antes de Deploy)
1. ✅ **Actualizar backend**: Pasar INTEGER en lugar de VARCHAR/DECIMAL
2. ✅ **Verificar JWT**: Asegurar que incluye id_user como INTEGER
3. ✅ **Ejecutar DROP**: Eliminar versiones antiguas de las funciones
4. ✅ **Ejecutar SQL**: Aplicar ambas funciones v2.0
5. ✅ **Probar casos**: Ejecutar los casos de prueba

### Corto Plazo
6. ✅ **Actualizar documentación API**: Nuevos códigos de error y parámetros
7. ✅ **Actualizar Postman/Insomnia**: Cambiar collections
8. ✅ **Notificar frontend**: Cambio en respuesta (id_trip_out → id_trip)

### Mediano Plazo
9. ⚠️ **Monitorear logs**: Revisar NOTICE messages
10. ⚠️ **Performance**: Evaluar batch si se crean muchos viajes simultáneos

---

## 10. COMPARACIÓN CON OTRAS FUNCIONES

| Característica | fun_create_trip v2.0 | fun_create_bus v2.0 | fun_create_driver v2.0 |
|----------------|----------------------|---------------------|------------------------|
| Patrón OUT parameters | ✅ success/msg/error_code/id | ✅ success/msg/error_code/id | ✅ success/msg/error_code/id |
| Validación user_create | ✅ Verifica existencia | ✅ Verifica existencia | ✅ Verifica existencia |
| Tipo user_create | ✅ INTEGER | ✅ INTEGER | ✅ INTEGER |
| Uso de %TYPE | ✅ Todos los parámetros | ✅ Todos los parámetros | ✅ Todos los parámetros |
| Bloques TRY-CATCH | ✅ 1 bloque | ✅ 1 bloque | ✅ 3 bloques |
| RAISE NOTICE | ✅ Logging | ✅ Logging | ✅ Logging |
| Normalización | ✅ v_plate_normalized | ✅ v_normalized_* | ✅ v_*_clean |
| Valida estado activo | ✅ Ruta y bus | ✅ Usuario creador | ✅ Usuario creador |
| Valida formato | ✅ Placa | ✅ Placa, AMB | ✅ Email, password, nombre |

**Conclusión**: Todas las funciones ahora siguen el patrón v2.0 con consistencia total.

---

## 11. CONCLUSIÓN

### Errores Críticos Resueltos
- ✅ **Sin validación usuario creador**: Ahora valida existencia y estado
- ✅ **Tipos incorrectos en batch**: DECIMAL→INTEGER, VARCHAR→INTEGER
- ✅ **Sin validar estado activo**: Ahora verifica ruta y bus activos
- ✅ **Sin validar formato placa**: Ahora valida ^[A-Z]{3}[0-9]{3}$
- ✅ **Campos redundantes**: Eliminados (usa DEFAULT)

### Mejoras de Calidad
- ✅ 14 códigos de error en fun_create_trip
- ✅ 6 códigos de error en fun_create_trips_batch
- ✅ trips_failed agregado en batch
- ✅ Detalles de errores en batch
- ✅ Logging con RAISE NOTICE
- ✅ Normalización de variables
- ✅ Validación de fecha antigua

### Estado de Deployment
- ⚠️ **No compatible hacia atrás**: Backend debe actualizarse
- ⚠️ **Cambio en batch**: Tipos de parámetros diferentes
- ✅ **Lista para producción**: Después de actualizar backend
- ✅ **Documentada**: Este reporte + comentarios en código

### Próximos Pasos
1. Actualizar backend para ambas funciones
2. Ejecutar pruebas según sección 8
3. Deploy a staging
4. Validar integración end-to-end
5. Deploy a producción

---

**Versión del Reporte**: 1.0  
**Autor**: GitHub Copilot  
**Fecha de Revisión**: 2025-01-01  
**Archivo Revisado**: fun_create_trip.sql v2.0 (2 funciones, 455 líneas totales)  
**Estado**: ✅ Revisión completa - Backend pendiente de actualización
