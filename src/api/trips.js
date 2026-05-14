import apiClient from './client'

/**
 * HELPERS para conversión epoch ↔ fecha/hora
 */

/**
 * Convierte Date a timestamp epoch (segundos)
 */
export function dateToEpoch(date) {
  return Math.floor(date.getTime() / 1000)
}

/**
 * Convierte timestamp epoch a Date
 */
export function epochToDate(epoch) {
  return new Date(epoch * 1000)
}

/**
 * Convierte epoch a formato legible
 */
export function formatEpochToDateTime(epoch) {
  const date = new Date(epoch * 1000)
  return date.toLocaleString('es-CO', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })
}

/**
 * Obtiene el timestamp actual en epoch
 */
export function getCurrentEpoch() {
  return Math.floor(Date.now() / 1000)
}

/**
 * Combina fecha (YYYY-MM-DD) + hora (HH:mm) → epoch
 */
export function dateTimeToEpoch(date, time) {
  const dateTimeString = `${date}T${time}`
  const dateObj = new Date(dateTimeString)
  return dateToEpoch(dateObj)
}

/**
 * Obtiene epoch para inicio del día (00:00:00)
 */
export function getStartOfDayEpoch(dateString) {
  const date = new Date(dateString + 'T00:00:00')
  return dateToEpoch(date)
}

/**
 * Obtiene epoch para fin del día (23:59:59)
 */
export function getEndOfDayEpoch(dateString) {
  const date = new Date(dateString + 'T23:59:59')
  return dateToEpoch(date)
}

/**
 * ENDPOINTS API
 */

/**
 * Lista viajes con filtros opcionales
 * @param {Object} filters - Filtros de búsqueda
 * @param {number} [filters.status_trip] - Filtrar por estado (1-5)
 * @param {number} [filters.id_route] - Filtrar por ruta
 * @param {number} [filters.id_driver] - Filtrar por conductor (cédula)
 * @param {string} [filters.plate_number] - Filtrar por placa del bus
 * @param {number} [filters.from_epoch] - Timestamp desde
 * @param {number} [filters.to_epoch] - Timestamp hasta
 * @param {number} [filters.limit=100] - Límite de resultados
 * @param {number} [filters.offset=0] - Offset para paginación
 * @returns {Promise<Object>} - { success, data: Array, pagination: Object }
 */
export async function listTrips(filters = {}) {
  const params = new URLSearchParams()
  
  Object.entries(filters).forEach(([key, value]) => {
    if (value !== undefined && value !== null && value !== '') {
      params.append(key, value)
    }
  })
  
  const queryString = params.toString()
  const url = `/trips${queryString ? '?' + queryString : ''}`
  
  const response = await apiClient.get(url)
  return response.data
}

/**
 * Obtener viajes por ruta y fecha (compatibilidad con código existente)
 * Convierte internamente a la nueva estructura epoch-based
 */
export async function getTripsByRouteAndDate(routeId, date) {
  const filters = {
    id_route: routeId,
    trip_date: date,
    limit: 500
  }
  
  const result = await listTrips(filters)
  return result.data || []
}

/**
 * Obtener un viaje por ID
 */
export async function getTripById(id) {
  const response = await apiClient.get(`/trips/${id}`)
  return response.data.data
}

/**
 * Obtener historial de eventos de un viaje
 */
export async function getTripEvents(id) {
  const response = await apiClient.get(`/trips/${id}/events`)
  return response.data.data
}

/**
 * Crear un viaje individual
 * @param {Object} tripData
 * @param {number} tripData.id_route - ID de la ruta
 * @param {string} tripData.trip_date - Fecha del viaje (YYYY-MM-DD)
 * @param {string} tripData.start_time - Hora de inicio (HH:mm:ss)
 * @param {string} tripData.end_time - Hora de fin (HH:mm:ss)
 * @param {string} [tripData.plate_number] - Placa del bus (opcional)
 * @param {number} [tripData.id_driver] - Cédula del conductor (opcional)
 * @param {number} [tripData.status_trip=1] - Estado (1-5, default 1=pending)
 * @returns {Promise<Object>} - { success, msg, id_trip, error_code }
 */
export async function createTrip(tripData) {
  const response = await apiClient.post('/trips', tripData)
  return response.data
}

/**
 * Crear múltiples viajes en lote
 * @param {Object} batchData
 * @param {number} batchData.id_route - ID de la ruta
 * @param {string} batchData.trip_date - Fecha de los viajes (YYYY-MM-DD)
 * @param {Array} batchData.trips - Array de viajes [{start_time, end_time, plate_number?, id_driver?, status_trip?}]
 * @returns {Promise<Object>} - { success, msg, trips_created, trips_failed, trip_ids }
 */
export async function createTripsBatch(batchData) {
  const response = await apiClient.post('/trips/batch', batchData)
  return response.data
}

/**
 * FUNCIONES LEGACY (mantenidas por compatibilidad pero NO IMPLEMENTADAS en nuevo backend)
 */

/**
 * Actualizar viaje existente
 * @param {number} id - ID del viaje
 * @param {Object} updateData - Datos a actualizar
 * @param {string} [updateData.start_time] - Nueva hora de inicio (HH:mm:ss)
 * @param {string} [updateData.end_time] - Nueva hora de fin (HH:mm:ss)
 * @param {string} [updateData.plate_number] - Nueva placa del bus
 * @param {number} [updateData.status_trip] - Nuevo estado (1-5)
 * @returns {Promise<Object>} - Respuesta con success, msg, id_trip
 */
export async function updateTrip(id, updateData) {
  const response = await apiClient.put(`/trips/${id}`, updateData)
  return response.data
}

/**
 * Cancelar un viaje individual (soft delete)
 * @param {number} id - ID del viaje a cancelar
 * @param {Object} options - Opciones de cancelación
 * @param {string} [options.cancellation_reason] - Razón de cancelación (obligatorio para viajes activos)
 * @param {boolean} [options.force_cancel=false] - Forzar cancelación de viajes activos
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

/**
 * Cancelar múltiples viajes de una ruta en una fecha específica (batch)
 * @param {Object} batchData - Datos de cancelación masiva
 * @param {number} batchData.id_route - ID de la ruta
 * @param {string} batchData.trip_date - Fecha de los viajes (YYYY-MM-DD)
 * @param {string} [batchData.cancellation_reason] - Razón de cancelación
 * @param {boolean} [batchData.force_cancel_active=false] - Forzar cancelación de viajes activos
 * @returns {Promise<Object>} - { success, msg, error_code, trips_cancelled, trips_active_skipped, cancelled_ids }
 */
export async function cancelTripsBatch(batchData) {
  const { id_route, trip_date, cancellation_reason = null, force_cancel_active = false } = batchData
  
  const response = await apiClient.delete('/trips/batch', {
    data: {
      id_route,
      trip_date,
      cancellation_reason,
      force_cancel_active
    }
  })
  
  return response.data
}

/**
 * FUNCIONES LEGACY DEPRECATED (mantenidas por compatibilidad mínima)
 */

/**
 * Asignar o desasignar bus (NO IMPLEMENTADO en nuevo backend)
 * @deprecated - Los viajes se crean con bus asignado desde el inicio
 */
export async function setTripBus(id, plateNumber, userUpdate) {
  console.warn('setTripBus() está deprecated - los viajes se asignan en creación')
  throw new Error('Función no disponible en la nueva arquitectura')
}

/**
 * Eliminar viaje (NO IMPLEMENTADO - use cancelTrip en su lugar)
 * @deprecated - Use cancelTrip() para soft delete
 */
export async function deleteTrip(id) {
  console.warn('deleteTrip() está deprecated - use cancelTrip() en su lugar')
  return cancelTrip(id, { cancellation_reason: 'Viaje eliminado' })
}

/**
 * Eliminar todos los viajes de una ruta/fecha (NO IMPLEMENTADO - use cancelTripsBatch)
 * @deprecated - Use cancelTripsBatch() para soft delete masivo
 */
export async function deleteTripsByDate(routeId, date) {
  console.warn('deleteTripsByDate() está deprecated - use cancelTripsBatch() en su lugar')
  return cancelTripsBatch({
    id_route: routeId,
    trip_date: date,
    cancellation_reason: 'Viajes eliminados masivamente'
  })
}
