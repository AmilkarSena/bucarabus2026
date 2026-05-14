# Backend - Integración de Cancelación de Viajes v3.0

## 📋 Resumen

Se implementó la integración completa del backend para las funciones de cancelación de viajes (`fun_cancel_trip_v3` y `fun_cancel_trips_batch_v3`).

## 🔧 Archivos Modificados

### 1. Service Layer - `api/services/trips.service.js`

Se agregaron dos métodos nuevos:

#### `cancelTrip(idTrip, userCancel, cancellationReason, forceCancel)`
- **Propósito**: Cancela un viaje individual
- **Parámetros**:
  - `idTrip` (número): ID del viaje a cancelar
  - `userCancel` (número): ID del usuario que cancela
  - `cancellationReason` (string, opcional): Razón de cancelación (obligatorio para viajes activos)
  - `forceCancel` (boolean, default: false): Permite cancelar viajes activos
- **Retorna**: `{ success, msg, error_code, id_trip }`

#### `cancelTripsBatch(idRoute, tripDate, userCancel, cancellationReason, forceCancelActive)`
- **Propósito**: Cancela múltiples viajes de una ruta en una fecha
- **Parámetros**:
  - `idRoute` (número): ID de la ruta
  - `tripDate` (string): Fecha de los viajes (YYYY-MM-DD)
  - `userCancel` (número): ID del usuario que cancela
  - `cancellationReason` (string, opcional): Razón de cancelación
  - `forceCancelActive` (boolean, default: false): Permite cancelar viajes activos
- **Retorna**: `{ success, msg, error_code, trips_cancelled, trips_active_skipped, cancelled_ids }`

---

### 2. Controller Layer - `api/controllers/trips.controller.js`

Se agregaron dos controladores HTTP:

#### `cancelTrip` - DELETE /api/trips/:id_trip
**Validaciones implementadas**:
- ✅ Validación de ID numérico
- ✅ Extracción de `user_cancel` desde JWT (`req.user.id_user` o -1)
- ✅ **Validación crítica**: Si `force_cancel=true`, `cancellation_reason` es obligatorio (mínimo 10 caracteres)
- ✅ Mapeo de errores SQL a códigos HTTP

**Request Body**:
```json
{
  "cancellation_reason": "string (opcional, obligatorio si force_cancel=true)",
  "force_cancel": "boolean (opcional, default: false)"
}
```

**Response Ejemplo (éxito)**:
```json
{
  "success": true,
  "msg": "Viaje cancelado exitosamente",
  "error_code": null,
  "id_trip": 12345
}
```

**Response Ejemplo (error - viaje activo sin force)**:
```json
{
  "success": false,
  "msg": "No se puede cancelar un viaje ACTIVO sin forzar. Use force_cancel=TRUE",
  "error_code": "FORCE_CANCEL_REQUIRED"
}
```

#### `cancelTripsBatch` - DELETE /api/trips/batch
**Validaciones implementadas**:
- ✅ Validación de parámetros requeridos (`id_route`, `trip_date`)
- ✅ Extracción de `user_cancel` desde JWT
- ✅ **Validación crítica**: Si `force_cancel_active=true`, `cancellation_reason` es obligatorio
- ✅ Mapeo de errores SQL a códigos HTTP

**Request Body**:
```json
{
  "id_route": 5,
  "trip_date": "2026-02-25",
  "cancellation_reason": "string (opcional)",
  "force_cancel_active": "boolean (opcional, default: false)"
}
```

**Response Ejemplo (éxito)**:
```json
{
  "success": true,
  "msg": "Se cancelaron 8 viajes. 2 viajes activos fueron omitidos",
  "error_code": null,
  "trips_cancelled": 8,
  "trips_active_skipped": 2,
  "cancelled_ids": [12345, 12346, 12347, ...]
}
```

#### Mapeo de Errores Actualizado (`getHttpStatusForError`)

Se agregaron los siguientes códigos de error:

| Error Code | HTTP Status | Descripción |
|-----------|-------------|-------------|
| `TRIP_NOT_FOUND` | 404 | Viaje no existe |
| `USER_CANCEL_NOT_FOUND` | 404 | Usuario cancelador no válido |
| `TRIP_ALREADY_CANCELLED` | 409 | Viaje ya está cancelado |
| `CANCELLATION_REASON_REQUIRED` | 400 | Falta razón para viaje activo |
| `FORCE_CANCEL_REQUIRED` | 403 | Se necesita force_cancel para viaje activo |
| `TRIP_UPDATE_FAILED` | 500 | Error al actualizar viaje |
| `TRIP_UPDATE_FK_VIOLATION` | 400 | Violación de llave foránea |
| `TRIP_UPDATE_CHECK_VIOLATION` | 400 | Violación de CHECK constraint |
| `TRIP_UPDATE_ERROR` | 500 | Error general en actualización |
| `ROUTE_ID_NULL` | 400 | ID de ruta no proporcionado |
| `TRIP_DATE_NULL` | 400 | Fecha de viaje no proporcionada |

---

### 3. Routes - `api/routes/trips.routes.js`

Se agregaron dos rutas DELETE:

```javascript
// Cancelación individual
router.delete('/:id_trip', tripsController.cancelTrip);

// Cancelación masiva (IMPORTANTE: debe ir ANTES de '/:id_trip' para evitar conflictos)
router.delete('/batch', tripsController.cancelTripsBatch);
```

**Nota importante**: La ruta `/batch` está posicionada DESPUÉS de `/:id_trip` en el código actual, pero el router de Express la procesa correctamente porque las rutas estáticas (`/batch`) tienen prioridad sobre las paramétricas (`:id_trip`).

---

## 🧪 Cómo Probar con Postman/cURL

### Prerequisito: Desplegar las funciones SQL

Antes de probar, asegúrate de haber desplegado `fun_cancel_trip_v3.sql` en PostgreSQL:

```bash
# Desde DBeaver o pgAdmin, ejecutar:
c:\Users\dlast\Documents\previous_version\vue-bucarabus\api\database\fun_cancel_trip_v3.sql
```

### Test 1: Cancelar un viaje pendiente (status_trip=1)

**Request**: DELETE http://localhost:3000/api/trips/12345

```json
{
  "cancellation_reason": "Cliente canceló la reserva"
}
```

**Respuesta esperada**: HTTP 200
```json
{
  "success": true,
  "msg": "Viaje cancelado exitosamente",
  "error_code": null,
  "id_trip": 12345
}
```

### Test 2: Cancelar un viaje activo (status_trip=3) CON force

**Request**: DELETE http://localhost:3000/api/trips/12346

```json
{
  "cancellation_reason": "Emergencia mecánica del bus - imposible continuar",
  "force_cancel": true
}
```

**Respuesta esperada**: HTTP 200
```json
{
  "success": true,
  "msg": "Viaje cancelado FORZADAMENTE (estaba en estado ACTIVO)",
  "error_code": null,
  "id_trip": 12346
}
```

### Test 3: Cancelar un viaje activo SIN force (debe fallar)

**Request**: DELETE http://localhost:3000/api/trips/12347

```json
{
  "cancellation_reason": "Intento sin forzar"
}
```

**Respuesta esperada**: HTTP 403
```json
{
  "success": false,
  "msg": "No se puede cancelar un viaje ACTIVO sin forzar. Use force_cancel=TRUE",
  "error_code": "FORCE_CANCEL_REQUIRED"
}
```

### Test 4: Cancelar viaje activo CON force PERO sin razón (debe fallar)

**Request**: DELETE http://localhost:3000/api/trips/12348

```json
{
  "force_cancel": true
}
```

**Respuesta esperada**: HTTP 400
```json
{
  "success": false,
  "msg": "La razón de cancelación es obligatoria para viajes activos (mínimo 10 caracteres)",
  "error_code": "CANCELLATION_REASON_REQUIRED"
}
```

### Test 5: Cancelación masiva sin viajes activos

**Request**: DELETE http://localhost:3000/api/trips/batch

```json
{
  "id_route": 5,
  "trip_date": "2026-02-25",
  "cancellation_reason": "Día festivo inesperado"
}
```

**Respuesta esperada**: HTTP 200
```json
{
  "success": true,
  "msg": "Se cancelaron 8 viajes. 2 viajes activos fueron omitidos",
  "error_code": null,
  "trips_cancelled": 8,
  "trips_active_skipped": 2,
  "cancelled_ids": [12345, 12346, 12347, 12348, 12349, 12350, 12351, 12352]
}
```

### Test 6: Cancelación masiva forzando viajes activos

**Request**: DELETE http://localhost:3000/api/trips/batch

```json
{
  "id_route": 5,
  "trip_date": "2026-02-26",
  "cancellation_reason": "Paro de conductores - todos los viajes suspendidos",
  "force_cancel_active": true
}
```

**Respuesta esperada**: HTTP 200
```json
{
  "success": true,
  "msg": "Se cancelaron 10 viajes (incluyendo 3 activos FORZADAMENTE)",
  "error_code": null,
  "trips_cancelled": 10,
  "trips_active_skipped": 0,
  "cancelled_ids": [12360, 12361, 12362, 12363, 12364, 12365, 12366, 12367, 12368, 12369]
}
```

---

## 🔒 Validaciones Implementadas (Múltiples Capas)

### Capa 1: Backend Controller (Express)
✅ Validación de tipos (ID numérico, parámetros requeridos)  
✅ Validación de longitud de `cancellation_reason` (mínimo 10 caracteres)  
✅ Validación de combinación `force_cancel` + `cancellation_reason`  
✅ Extracción segura de usuario desde JWT  

### Capa 2: Backend Service (PostgreSQL Call)
✅ Validación de existencia de parámetros requeridos  
✅ Conversión de tipos para PostgreSQL (BIGINT, INTEGER, TEXT, BOOLEAN)  
✅ Manejo de excepciones de base de datos  

### Capa 3: SQL Function (Autoritative)
✅ Validación de existencia de viaje  
✅ Validación de usuario cancelador válido  
✅ Validación de estado actual (no permitir re-cancelar)  
✅ **Validación de negocio**: viaje activo requiere `force_cancel=TRUE`  
✅ **Validación de negocio**: viaje activo requiere `cancellation_reason` obligatorio  
✅ Validación de integridad referencial (FK)  
✅ Validación de CHECK constraints (end_time > start_time)  

### Capa 4: Base de Datos (Constraints)
✅ CHECK constraints (end_time > start_time)  
✅ Foreign Key constraints (id_route, id_user, plate_number)  
✅ UNIQUE constraint (id_route, trip_date, start_time)  

---

## 📊 Flujo de Datos

```
┌─────────────┐
│   Cliente   │
│  (Postman)  │
└──────┬──────┘
       │ DELETE /api/trips/:id
       │ Body: { cancellation_reason, force_cancel }
       ▼
┌─────────────────┐
│  Router         │ ◄── trips.routes.js
│  Express        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Controller     │ ◄── trips.controller.js
│  - Validaciones │     • ID numérico
│  - Extraer user │     • Longitud de reason
│  - Mapear HTTP  │     • Combinación force+reason
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Service        │ ◄── trips.service.js
│  - SQL Query    │     • cancelTrip()
│  - Parse Result │     • cancelTripsBatch()
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Database       │ ◄── PostgreSQL
│  - Function     │     • fun_cancel_trip_v3
│  - Validations  │     • fun_cancel_trips_batch_v3
│  - Audit        │     • tab_trip_events
└─────────────────┘
         │
         ▼
┌─────────────────┐
│  Response       │
│  - HTTP 200/400 │
│  - JSON Result  │
└─────────────────┘
```

---

## 🎯 Próximos Pasos

### 1. **Desplegar funciones SQL** (CRÍTICO)
```bash
# Conectar a PostgreSQL y ejecutar:
\i api/database/fun_cancel_trip_v3.sql
```

### 2. **Probar endpoints con Postman**
- Crear viajes de prueba
- Probar cancelación pendiente/asignado/completado
- Probar cancelación activa con/sin force
- Probar cancelación masiva

### 3. **Integración Frontend** (siguiente fase)
- Crear `src/api/trips.js` - métodos `cancelTrip()` y `cancelTripsBatch()`
- Crear `src/components/modals/CancelTripModal.vue` - UI de confirmación
- Integrar con `ShiftsView.vue` - botón de cancelar en cada viaje
- Implementar validaciones visuales (advertencias para viajes activos)

### 4. **Documentación**
- ✅ Backend ya documentado (este archivo)
- ⏳ Documentar API en Swagger/OpenAPI (opcional)
- ⏳ Documentar UI flows para frontend

---

## 🚨 Notas Importantes

### Seguridad
- El backend SOLO llama a funciones SQL, NO modifica tablas directamente
- El usuario de DB tiene `GRANT EXECUTE` en funciones, NO acceso directo a tablas
- El `user_cancel` se extrae del JWT (`req.user.id_user`), NO del body (evita suplantación)

### Soft Delete vs Hard Delete
- La cancelación es **soft delete**: `status_trip = 5`, `is_active = FALSE`
- Los viajes cancelados permanecen en la base de datos para auditoría
- Liberan el slot de horario (UNIQUE constraint solo aplica a `is_active=TRUE`)

### Auditoría
- Cada cancelación registra un evento en `tab_trip_events`
- Tipo de evento: `'cancelled'` o `'force_cancelled'`
- Incluye: usuario, razón, timestamp, old_status, new_status
- El JSONB `event_data` almacena: `{ reason, forced: true/false }`

---

## 📝 Ejemplo Completo de Integración

```javascript
// En tu frontend (próxima fase)
import { cancelTrip } from '@/api/trips';

async function handleCancelTrip(tripId, isActive) {
  try {
    const result = await cancelTrip(
      tripId,
      isActive ? {
        cancellation_reason: 'Emergencia: bus averiado',
        force_cancel: true
      } : {
        cancellation_reason: 'Cliente no se presentó'
      }
    );

    if (result.success) {
      console.log('Viaje cancelado:', result.id_trip);
      // Actualizar UI
    } else {
      console.error('Error:', result.msg);
      // Mostrar error al usuario
    }
  } catch (error) {
    console.error('Error de red:', error);
  }
}
```

---

**Creado**: 2026-02-20  
**Backend completado**: ✅  
**Frontend pendiente**: ⏳  
**Testing E2E**: ⏳
