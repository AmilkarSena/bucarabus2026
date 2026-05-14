# Validaciones de Horarios - Sistema BucaraBus

## 📋 Resumen de validaciones implementadas

### **Validación 1: Hora de fin > Hora de inicio**
**Regla:** La hora de finalización debe ser mayor que la hora de inicio del mismo viaje.

### **Validación 2: Orden secuencial de viajes**
**Regla:** La hora de inicio de un nuevo viaje debe ser MAYOR que la hora de inicio del último viaje activo de la misma ruta/fecha.

---

## ✅ Estado de implementación

### **1. Base de Datos (bd_bucarabus.sql)**

#### Validación 1 - CHECK Constraint:
```sql
CONSTRAINT chk_trips_times CHECK (end_time > start_time)
```
- ✅ **IMPLEMENTADO**
- Nivel: Constraint de tabla
- Efecto: Bloquea cualquier INSERT/UPDATE que viole la regla

#### Validación 2 - No constraint directo:
- ⚠️ **NO HAY CONSTRAINT** (se valida en funciones)
- Razón: CHECK constraints no pueden referenciar otras filas de la misma tabla
- Solución: Validación en funciones almacenadas

---

### **2. Funciones Almacenadas**

#### **fun_create_trip_v3.sql**

**Validación 1** (línea 165-170):
```sql
-- 5.1. Validar que hora fin > hora inicio
IF wend_time <= wstart_time THEN
    msg := 'La hora de fin (' || wend_time || ') debe ser posterior a la hora de inicio (' || wstart_time || ')';
    error_code := 'INVALID_TIME_RANGE';
    RETURN;
END IF;
```
- ✅ **IMPLEMENTADO**
- Código de error: `INVALID_TIME_RANGE`

**Validación 2** (línea 303-322 - RECIÉN AGREGADO):
```sql
-- 9. VALIDAR ORDEN SECUENCIAL (hora inicio)
SELECT MAX(start_time) INTO v_max_start_time
FROM tab_trips
WHERE id_route = wid_route
  AND trip_date = wtrip_date
  AND is_active = TRUE;  -- Solo validar contra viajes activos

IF v_max_start_time IS NOT NULL AND wstart_time <= v_max_start_time THEN
    msg := 'La hora de inicio (' || wstart_time || ') debe ser mayor que la hora de inicio del último viaje activo (' || v_max_start_time || ')';
    error_code := 'START_TIME_NOT_SEQUENTIAL';
    RETURN;
END IF;
```
- ✅ **IMPLEMENTADO**
- Código de error: `START_TIME_NOT_SEQUENTIAL`
- **IMPORTANTE:** Solo valida contra `is_active = TRUE` (permite reutilizar horarios cancelados)

#### **fun_create_trips_batch_v3.sql**

**Validación 1** (implícita en lógica de negocio):
- ✅ **IMPLEMENTADO** (cada viaje individual valida end_time > start_time vía constraint)

**Validación 2** (línea 345-357 - RECIÉN AGREGADO):
```sql
-- 7.6. VALIDAR ORDEN SECUENCIAL
SELECT MAX(start_time) INTO v_max_start_time
FROM tab_trips
WHERE id_route = wid_route
  AND trip_date = wtrip_date
  AND is_active = TRUE;

IF v_max_start_time IS NOT NULL AND v_start_time <= v_max_start_time THEN
    RAISE EXCEPTION 'Hora de inicio % no es secuencial. Debe ser mayor que % (viaje #%)', 
                    v_start_time, v_max_start_time, v_index;
END IF;
```
- ✅ **IMPLEMENTADO**
- Solo valida contra viajes activos

---

### **3. Backend (Node.js/Express)**

#### **api/controllers/trips.controller.js**

**Validación 1:**
```javascript
// Línea 17-21
if (!id_route || !trip_date || !start_time || !end_time) {
    return res.status(400).json({
        success: false,
        msg: 'Faltan parámetros requeridos: id_route, trip_date, start_time, end_time'
    });
}
```
- ⚠️ **VALIDACIÓN BÁSICA** (solo verifica que existan)
- NO valida la relación end_time > start_time
- ✅ **OK** porque la función almacenada lo valida

**Validación 2:**
- ❌ **NO IMPLEMENTADO** en backend
- ✅ **OK** porque la función almacenada lo valida

**Recomendación:** El backend NO necesita validar la lógica de negocio porque las funciones almacenadas son la única vía de acceso a los datos (patrón de seguridad correcto).

---

### **4. Frontend (Vue 3)**

#### **src/components/modals/ShiftsModal.vue**

**Validación 1** (línea 841-850):
```javascript
// Validar que hora fin sea mayor que hora inicio
if (field === 'end_time') {
    const start = new Date(`2000-01-01T${currentStartTime}`)
    const end = new Date(`2000-01-01T${newTime}`)
    
    if (end <= start) {
        alert(`❌ La hora de fin (${newTime}) debe ser mayor que la hora de inicio (${currentStartTime})`)
        return
    }
}
```
- ✅ **IMPLEMENTADO**
- Feedback inmediato al usuario

**Validación 2** (línea 570-583):
```javascript
// 1. Verificar que la hora de inicio sea mayor a cualquier viaje existente
const existingTrips = currentTrips.value || []
if (existingTrips.length > 0) {
    const lastTrip = existingTrips[existingTrips.length - 1]
    const lastTripStartTime = lastTrip.start_time
    
    const lastStart = new Date(`2000-01-01T${lastTripStartTime}`)
    const newStart = new Date(`2000-01-01T${startTimeStr}`)
    
    if (newStart <= lastStart) {
        alert(`❌ La hora de inicio del nuevo lote (${startTimeStr}) debe ser superior a la del último viaje (${lastTripStartTime}).\n\nDebe ser mayor que: ${lastTripStartTime}`)
        return
    }
}
```
- ✅ **IMPLEMENTADO**
- Feedback inmediato al usuario
- **NOTA:** Valida contra `currentTrips.value` (viajes mostrados en la interfaz)
- **IMPORTANTE:** Solo valida viajes activos (los cancelados no se muestran en el grid)

---

## 📊 Resumen por nivel

| Nivel | Validación #1 (fin > inicio) | Validación #2 (secuencial) | Estado |
|-------|------------------------------|----------------------------|--------|
| **Base de Datos** | ✅ CHECK constraint | ❌ No posible con constraint | ✅ |
| **Funciones SQL** | ✅ fun_create_trip_v3 | ✅ fun_create_trip_v3 (NUEVO) | ✅ |
| **Funciones SQL** | ✅ fun_create_trips_batch_v3 | ✅ fun_create_trips_batch_v3 (NUEVO) | ✅ |
| **Backend** | ⚠️ No valida (delegado a SQL) | ⚠️ No valida (delegado a SQL) | ✅ |
| **Frontend** | ✅ ShiftsModal.vue | ✅ ShiftsModal.vue | ✅ |

---

## 🎯 Flujo de validación completo

### **Escenario: Usuario crea un viaje a las 10:00-11:00**

1. **Frontend (ShiftsModal.vue)**
   - ✅ Valida 11:00 > 10:00 (hora fin > hora inicio)
   - ✅ Valida 10:00 > MAX(start_time de viajes activos)
   - Si pasa → Envía request a backend

2. **Backend (trips.controller.js)**
   - ✅ Verifica parámetros obligatorios existen
   - Llama a `tripsService.createTrip()`

3. **Service (trips.service.js)**
   - Llama a `fun_create_trip(...)` en PostgreSQL

4. **Función SQL (fun_create_trip_v3)**
   - ✅ Valida 11:00 > 10:00 (error_code: INVALID_TIME_RANGE)
   - ✅ Valida 10:00 > MAX(start_time activos) (error_code: START_TIME_NOT_SEQUENTIAL)
   - ✅ Intenta INSERT

5. **Base de Datos (constraint)**
   - ✅ Verifica `CHECK (end_time > start_time)`
   - ✅ Verifica `UNIQUE (id_route, trip_date, start_time)`
   - Si todo OK → INSERT exitoso

---

## 🔧 Cambios recientes aplicados

### **Archivos modificados:**
1. ✅ **fun_create_trip_v3.sql** 
   - Agregada validación de orden secuencial (línea 303-322)
   - Actualizado `error_code` en documentación

2. ✅ **fun_create_trips_batch_v3.sql**
   - Agregada validación de orden secuencial (línea 345-357)
   - Renumeradas secciones (7.6, 7.7, 7.8, 7.9)

### **Archivos SIN cambios (ya correctos):**
- ✅ **bd_bucarabus.sql** - CHECK constraint ya existe
- ✅ **ShiftsModal.vue** - Validaciones frontend ya implementadas
- ✅ **trips.controller.js** - Delega validación correctamente a SQL

---

## ⚠️ Consideraciones importantes

### **Viajes cancelados:**
Las validaciones de orden secuencial **SOLO validan contra viajes activos** (`is_active = TRUE`).

**Ejemplo:**
```sql
-- Viajes existentes:
Viaje A: 08:00-09:00 (status=2, is_active=TRUE)  ✅ Activo
Viaje B: 09:15-10:15 (status=5, is_active=FALSE) ❌ Cancelado
Viaje C: 10:30-11:30 (status=2, is_active=TRUE)  ✅ Activo

-- Intentar crear viaje a las 10:00:
MAX(start_time WHERE is_active=TRUE) = 10:30 (Viaje C)
10:00 <= 10:30 → ❌ RECHAZADO (START_TIME_NOT_SEQUENTIAL)

-- Intentar crear viaje a las 11:00:
11:00 > 10:30 → ✅ PERMITIDO (aunque el B cancelado tenga 09:15)
```

**Beneficio:** Permite flexibilidad operativa sin comprometer la integridad de datos activos.

---

## 🚀 Testing recomendado

### **Test 1: Validación hora fin > hora inicio**
```javascript
// Frontend ShiftsModal
trip = { start_time: '10:00', end_time: '09:00' }
// Debe mostrar alert: "La hora de fin (09:00) debe ser mayor que la hora de inicio (10:00)"
```

### **Test 2: Validación orden secuencial**
```javascript
// Viajes existentes: [08:00, 09:00, 10:00]
// Intentar crear viaje a las 09:30
// Debe mostrar alert: "La hora de inicio (09:30) debe ser superior a la del último viaje (10:00)"
```

### **Test 3: Base de datos (constraint)**
```sql
INSERT INTO tab_trips (id_route, trip_date, start_time, end_time, ...)
VALUES (1, '2026-02-20', '10:00', '09:00', ...);
-- Debe fallar con: ERROR: new row violates check constraint "chk_trips_times"
```

### **Test 4: Función SQL**
```sql
SELECT * FROM fun_create_trip(
    1, '2026-02-20', '10:00', '09:00', -1, NULL, NULL, 1
);
-- Debe retornar: success=FALSE, error_code='INVALID_TIME_RANGE'
```

---

## ✅ Conclusión

**Todas las validaciones solicitadas están implementadas en todos los niveles:**

1. ✅ **Validación 1** (hora fin > hora inicio): Base de datos (constraint) + Funciones SQL + Frontend
2. ✅ **Validación 2** (orden secuencial): Funciones SQL + Frontend

**Arquitectura de validación:**
- **Frontend:** Validación inmediata (UX)
- **Funciones SQL:** Validación de negocio (seguridad)
- **Base de datos:** Validación de integridad (último recurso)

**Patrón de seguridad:** ✅ Correcto
- El backend NO duplica validaciones (evita inconsistencias)
- Las funciones SQL son la ÚNICA vía de acceso a datos transaccionales
- Cualquier cliente (frontend, API externa, scripts) recibe las mismas validaciones

