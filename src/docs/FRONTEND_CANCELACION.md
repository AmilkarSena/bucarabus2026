# Frontend - Integración de Cancelación de Viajes v3.0

## 📋 Resumen

Se implementó la integración completa del frontend para las funciones de cancelación de viajes, incluyendo validaciones visuales y flujos de confirmación diferenciados según el estado del viaje.

## 🔧 Archivos Modificados

### 1. API Client - `src/api/trips.js`

Se actualizaron las funciones de cancelación que estaban marcadas como deprecated:

#### `cancelTrip(id, options)` - ACTUALIZADA ✅
**Antes**: Función deprecated que lanzaba error
**Ahora**: Función completa que llama al endpoint DELETE

```javascript
/**
 * @param {number} id - ID del viaje a cancelar
 * @param {Object} options
 * @param {string} [options.cancellation_reason] - Razón (obligatorio para activos)
 * @param {boolean} [options.force_cancel=false] - Forzar cancelación de activos
 * @returns {Promise<Object>} - { success, msg, error_code, id_trip }
 */
export async function cancelTrip(id, options = {}) {
  const { cancellation_reason = null, force_cancel = false } = options
  
  const response = await apiClient.delete(`/trips/${id}`, {
    data: {
      cancellation_reason,
      force_cancel
    }
  })
  
  return response.data
}
```

#### `cancelTripsBatch(batchData)` - NUEVA ✅
Función completamente nueva para cancelación masiva:

```javascript
/**
 * @param {Object} batchData
 * @param {number} batchData.id_route - ID de la ruta
 * @param {string} batchData.trip_date - Fecha (YYYY-MM-DD)
 * @param {string} [batchData.cancellation_reason] - Razón
 * @param {boolean} [batchData.force_cancel_active=false] - Forzar activos
 * @returns {Promise<Object>} - { success, msg, trips_cancelled, trips_active_skipped, cancelled_ids }
 */
export async function cancelTripsBatch(batchData) {
  // ...implementación
}
```

#### Funciones Deprecated Actualizadas
Las funciones `deleteTrip()` y `deleteTripsByDate()` ahora redirigen internamente a `cancelTrip()` y `cancelTripsBatch()` con mensajes de advertencia en consola.

---

### 2. Modal de Turnos - `src/components/modals/ShiftsModal.vue`

#### Cambios en Imports

```javascript
// ANTES:
import { updateTrip, deleteTrip as deleteTripAPI } from '../../api/trips'
import { SYSTEM_USER_ID } from '../../constants/system'

// AHORA:
import { updateTrip, cancelTrip as cancelTripAPI } from '../../api/trips'
import { SYSTEM_USER_ID } from '../../constants/system'
import { TRIP_STATUS } from '../../constants/tripStatuses'
```

#### Actualización de `loadExistingTrips()`

Se agregó el campo `status_trip` a los viajes cargados desde la base de datos:

```javascript
const convertedTrips = existingTrips.map((trip, index) => {
  return {
    // ...campos existentes
    status_trip: trip.status_trip,  // ✅ NUEVO: Estado numérico (1-5)
    fromDatabase: true,
    modified: false
  }
})
```

#### Actualización de `deleteTrip(trip)` - Con Validaciones ⚠️

La función ahora implementa un flujo completo de validación según el estado del viaje:

**Flujo para Viajes ACTIVOS (status_trip === 3):**

1. **Confirmación de advertencia** con `confirm()`
   - Mensaje: "⚠️ Este viaje está ACTIVO (en curso)"
   - Si el usuario cancela → ABORTAR proceso

2. **Solicitud de razón obligatoria** con `prompt()`
   - Mínimo 10 caracteres
   - Si la razón es inválida → ABORTAR proceso

3. **Marcar para cancelación**
   ```javascript
   deletedTripIds.value.push({ 
     id: trip.id, 
     force_cancel: true,
     cancellation_reason: reason.trim()
   })
   ```

**Flujo para Viajes NO ACTIVOS (pending/assigned/completed):**

1. **Solicitud de razón opcional** con `prompt()`
   - Valor por defecto: "Viaje cancelado"
   - No es obligatorio (puede quedar vacío)

2. **Marcar para cancelación**
   ```javascript
   deletedTripIds.value.push({ 
     id: trip.id,
     force_cancel: false,
     cancellation_reason: reason || 'Viaje cancelado desde interfaz'
   })
   ```

**Cambio en estructura de `deletedTripIds`:**

```javascript
// ANTES (solo IDs):
deletedTripIds.value = [12345, 12346, 12347]

// AHORA (objetos con opciones):
deletedTripIds.value = [
  { id: 12345, force_cancel: false, cancellation_reason: "..." },
  { id: 12346, force_cancel: true, cancellation_reason: "Emergencia..." }
]
```

#### Actualización de `saveSchedule()` - Sección de Cancelación

La sección que procesaba eliminaciones se actualizó para usar la nueva API:

```javascript
// 2. Cancelar viajes marcados para eliminación (soft delete)
if (deletedIds.length > 0) {
  console.log('🗑️ Cancelando viajes...')
  
  for (const tripData of deletedIds) {
    try {
      // Soporte para formato antiguo (solo ID) y nuevo formato (objeto)
      const tripId = typeof tripData === 'object' ? tripData.id : tripData
      const options = typeof tripData === 'object' ? {
        cancellation_reason: tripData.cancellation_reason,
        force_cancel: tripData.force_cancel || false
      } : {
        cancellation_reason: 'Viaje cancelado desde interfaz'
      }
      
      const result = await cancelTripAPI(tripId, options)
      
      if (result.success) {
        deletedCount++
        console.log(`✅ Viaje ${tripId} cancelado`)
      } else {
        errors.push(`Cancelación de viaje ${tripId}: ${result.msg}`)
      }
    } catch (error) {
      const errorMsg = error.response?.data?.msg || error.message
      errors.push(`Error cancelando viaje: ${errorMsg}`)
    }
  }
  
  deletedTripIds.value = []
}
```

**Compatibilidad hacia atrás**: El código soporta tanto el formato antiguo (array de IDs) como el nuevo (array de objetos) para facilitar la migración.

#### Actualización de Mensajes de Usuario

Los mensajes de éxito y error parcial se actualizaron para usar "cancelados" en lugar de "eliminados":

```javascript
// Mensaje de éxito:
'✅ Horario guardado exitosamente\n• 5 viajes actualizados\n• 3 viajes cancelados\n• 2 viajes creados'

// Mensaje de error parcial:
'⚠️ Guardado parcial:\n• 5 actualizados\n• 3 cancelados\n• 2 creados\n\nErrores:\n...'
```

---

## 🔒 Validaciones Implementadas (Frontend)

### Capa de UI - ShiftsModal.vue

✅ **Validación de Estado del Viaje**
- Detecta viajes activos (status_trip === 3)
- Muestra advertencia visual diferenciada

✅ **Validación de Confirmación Doble para Activos**
- Primer confirm(): Advertencia sobre impacto del viaje activo
- Usuario puede abortar antes de seguir

✅ **Validación de Razón de Cancelación**
- Viajes activos: Razón OBLIGATORIA (min 10 caracteres)
- Viajes no activos: Razón OPCIONAL pero recomendada
- Validación de longitud mínima antes de enviar

✅ **Validación de Formato de Datos**
- Conversión correcta de estructura antigua → nueva
- Soporte de retrocompatibilidad

### Capa de API Client - trips.js

✅ **Validación de Parámetros**
- Validación de ID numérico
- Construcción correcta del payload DELETE
- Manejo de opciones con valores por defecto

✅ **Manejo de Errores HTTP**
- Propagación correcta de errores del backend
- Formateo de mensajes de error para el usuario

---

## 🎯 Flujos de Usuario Implementados

### Flujo 1: Cancelar Viaje Pendiente/Asignado/Completado

```
Usuario hace clic en [🗑️] del viaje
    ↓
Prompt: "Razón de cancelación (opcional)"
Usuario ingresa: "Cliente no se presentó"
    ↓
Viaje se marca para cancelación con {
  force_cancel: false,
  cancellation_reason: "Cliente no se presentó"
}
    ↓
Usuario hace clic en [Guardar Horario]
    ↓
Backend procesa: cancelTripAPI(id, options)
    ↓
✅ Mensaje: "3 viajes cancelados"
    ↓
Modal se cierra, calendario se actualiza
```

### Flujo 2: Cancelar Viaje ACTIVO (en curso)

```
Usuario hace clic en [🗑️] del viaje activo
    ↓
⚠️ Confirm: "Este viaje está ACTIVO. ¿Continuar?"
Usuario hace clic en [Cancelar] → ABORTAR
Usuario hace clic en [Aceptar] → CONTINUAR
    ↓
Prompt: "Razón de cancelación (mínimo 10 caracteres)"
Usuario ingresa: "Emergencia: bus averiado en carretera"
    ↓
Validación: reason.length >= 10
Si falla → Alert: "Razón obligatoria (min 10 chars)" → ABORTAR
Si pasa → CONTINUAR
    ↓
Viaje se marca para cancelación con {
  force_cancel: true,
  cancellation_reason: "Emergencia: bus averiado en carretera"
}
    ↓
Usuario hace clic en [Guardar Horario]
    ↓
Backend procesa con force_cancel=true
    ↓
✅ Mensaje: "1 viaje cancelado (forzado)"
    ↓
Evento registrado como 'force_cancelled' en BD
```

### Flujo 3: Intentar Cancelar Viaje Activo con Razón Corta

```
Usuario hace clic en [🗑️] del viaje activo
    ↓
⚠️ Confirm: "Este viaje está ACTIVO. ¿Continuar?"
Usuario hace clic en [Aceptar]
    ↓
Prompt: "Razón de cancelación (mínimo 10 caracteres)"
Usuario ingresa: "Error"   ← Solo 5 caracteres
    ↓
❌ Alert: "Error: Razón obligatoria para viajes activos (mínimo 10 caracteres)"
    ↓
ABORTAR: Viaje NO se marca para cancelación
Viaje permanece en la lista
```

---

## 📊 Diagrama de Flujo de Datos

```
┌─────────────────┐
│  ShiftsModal    │
│  (UI Layer)     │
└────────┬────────┘
         │ clicks [🗑️]
         ↓
┌─────────────────┐
│  deleteTrip()   │
│  - Validate     │───❌ Usuario cancela
│  - Confirm      │
│  - Mark for del │
└────────┬────────┘
         │ trips marked
         ↓
┌─────────────────┐
│ deletedTripIds  │
│ [{ id, force,   │
│    reason }]    │
└────────┬────────┘
         │ User clicks [Guardar]
         ↓
┌─────────────────┐
│  saveSchedule() │
│  - Process IDs  │
│  - Call API     │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│ cancelTripAPI() │ ◄── src/api/trips.js
│  DELETE /trips  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Backend API    │ ◄── api/controllers/trips.controller.js
│  - Validate     │
│  - Map errors   │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Service Layer  │ ◄── api/services/trips.service.js
│  - Call SQL fn  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  PostgreSQL     │ ◄── fun_cancel_trip_v3
│  - Execute fn   │
│  - Update DB    │
│  - Log event    │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Response       │
│  { success,     │
│    msg, ... }   │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  UI Update      │
│  - Invalidate   │
│  - Reload data  │
│  - Show message │
└─────────────────┘
```

---

## 🧪 Cómo Probar la Integración

### Prerequisitos

1. **Backend corriendo** en `http://localhost:3000`
2. **Funciones SQL desplegadas** (fun_cancel_trip_v3.sql)
3. **Frontend corriendo** en `http://localhost:5173`

### Test 1: Cancelar Viaje Pendiente

1. Abrir ShiftsView en el navegador
2. Seleccionar una ruta y fecha con viajes pendientes
3. Hacer clic en el ícono 🗑️ de un viaje sin bus asignado
4. Ingresar razón: "Prueba de cancelación"
5. Hacer clic en [Guardar Horario]
6. **Resultado esperado**: 
   - Alert: "✅ 1 viaje cancelado"
   - Viaje desaparece del calendario
   - Estado en BD: status_trip=5, is_active=FALSE

### Test 2: Cancelar Viaje Activo (Simulado)

**Preparación**: Crear un viaje y cambiar manualmente su status_trip a 3 en PostgreSQL:

```sql
UPDATE tab_trips 
SET status_trip = 3, started_at = NOW() 
WHERE id_trip = 12345;
```

**Prueba**:
1. Abrir ShiftsModal con ese viaje
2. Hacer clic en 🗑️ del viaje activo
3. **Confirm**: "⚠️ Este viaje está ACTIVO..." → Aceptar
4. **Prompt**: Ingresar "Emergencia mecánica del bus en la ruta"
5. Hacer clic en [Guardar Horario]
6. **Resultado esperado**:
   - Alert: "✅ 1 viaje cancelado"
   - Viaje cancelado en BD
   - Evento en tab_trip_events con type='force_cancelled'

### Test 3: Viaje Activo - Razón Corta (Debe Fallar)

1. Repetir pasos del Test 2
2. En el prompt de razón, ingresar solo "Error"
3. **Resultado esperado**:
   - ❌ Alert: "Error: Razón obligatoria... (mínimo 10 caracteres)"
   - Viaje NO se cancela
   - Viaje permanece en la lista

### Test 4: Viaje Activo - Usuario Cancela Confirmación

1. Repetir pasos del Test 2
2. En el confirm de advertencia, hacer clic en [Cancelar]
3. **Resultado esperado**:
   - Proceso abortado inmediatamente
   - No se solicita razón
   - Viaje permanece intacto

### Test 5: Cancelación Masiva (Futuro)

Actualmente no hay UI para cancelación masiva en ShiftsModal, pero la API ya está lista.

---

## 📝 Resumen de Estados de Viaje

| Estado | Valor | Cancelación | Requiere force_cancel | Requiere reason |
|--------|-------|-------------|----------------------|-----------------|
| Pendiente | 1 | ✅ Siempre | ❌ No | ⚠️ Opcional |
| Asignado | 2 | ✅ Siempre | ❌ No | ⚠️ Opcional |
| Activo | 3 | ⚠️ Con fuerza | ✅ Sí | ✅ Sí (min 10 chars) |
| Completado | 4 | ✅ Siempre | ❌ No | ⚠️ Opcional |
| Cancelado | 5 | ❌ Ya cancelado | N/A | N/A |

---

## 🚨 Errores Manejados

| Código HTTP | Error Code | Mensaje | Causa |
|-------------|-----------|---------|-------|
| 404 | TRIP_NOT_FOUND | "Viaje no encontrado" | ID inválido |
| 409 | TRIP_ALREADY_CANCELLED | "Viaje ya cancelado" | Re-cancelación |
| 403 | FORCE_CANCEL_REQUIRED | "Viaje activo requiere force_cancel" | Viaje activo sin force |
| 400 | CANCELLATION_REASON_REQUIRED | "Razón obligatoria para viajes activos" | Activo sin razón |
| 400 | Invalid ID | "ID de viaje inválido" | ID no numérico |

---

## 🔄 Mejoras Futuras Sugeridas

### 1. Modal de Cancelación Dedicado (Alta Prioridad)

Crear `src/components/modals/CancelTripModal.vue` con:
- ✅ Diseño visual diferenciado (rojo para activos, amarillo para otros)
- ✅ Campo de texto multilinea para razón (en lugar de prompt())
- ✅ Checkbox de confirmación para activos: "Entiendo el impacto"
- ✅ Validación en tiempo real de longitud de razón
- ✅ Preview de información del viaje (ruta, hora, bus, conductor)

### 2. Indicadores Visuales en Lista de Viajes

- 🟢 Badge "Pendiente" para status_trip=1
- 🔵 Badge "Asignado" para status_trip=2
- 🟡 Badge "Activo" para status_trip=3 + animación pulsante
- ✅ Badge "Completado" para status_trip=4
- 🔴 Badge "Cancelado" para status_trip=5 + strikethrough

### 3. Función de Cancelación Masiva en UI

Agregar botón "Cancelar Todos los Viajes de Hoy" en ShiftsView:
- Muestra diálogo con lista de viajes a cancelar
- Opción de forzar activos con razón única
- Preview de impacto (cuántos activos, cuántos pasajeros afectados)

### 4. Historial de Cancelaciones

Vista de eventos de cancelación con:
- Usuario que canceló
- Razón de cancelación
- Timestamp
- Tipo (normal vs forzada)

### 5. Validación de Permisos por Rol

Actualmente no hay validación de roles en frontend:
- Solo admin/supervisor deberían poder forzar cancelación de activos
- Conductores solo pueden cancelar sus propios viajes
- Operadores solo pueden cancelar pending/assigned

---

## 📚 Recursos

- [Documentación Backend](BACKEND_CANCELACION.md)
- [Documentación Validaciones](VALIDACIONES_HORARIOS.md)
- [API Trip Statuses](src/constants/tripStatuses.js)

---

**Creado**: 2026-02-20  
**Backend**: ✅ Completo  
**Frontend**: ✅ Completo  
**Testing E2E**: ⏳ Pendiente  
**Modal Dedicado**: ⏳ Pendiente (mejora futura)
