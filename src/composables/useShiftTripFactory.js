// src/composables/useShiftTripFactory.js

/**
 * Composable especializado en la transformación y modelado del objeto "Trip" (Viaje).
 * 
 * Este módulo actúa como una "fábrica" (Factory) de datos:
 * 1. Mapeo de Esquemas: Traduce el objeto complejo que viene de la base de datos (con snake_case) 
 *    al formato reactivo y plano que usa el frontend.
 * 2. Creación Dinámica: Implementa la lógica para insertar nuevos viajes en medio de una lista existente,
 *    calculando automáticamente horas de inicio/fin para evitar solapamientos inmediatos.
 * 3. Normalización: Asegura que todos los objetos de viaje tengan el mismo "schema" de propiedades 
 *    (isEditing, fromDatabase, batchColor, etc.), facilitando su manejo en componentes de Vue.
 */
export function useShiftTripFactory() {

  /**
   * Convierte un viaje del formato de base de datos al formato del frontend.
   *
   * @param {Object} dbTrip     - Objeto tal como llega de la BD (id_trip, start_time, etc.)
   * @param {number} index      - Índice en el array (para asignar tripNumber)
   * @param {string|number} routeId  - ID de la ruta
   * @param {Array}  batchColors     - Array de colores de lote [{ color, icon }]
   * @param {Function} calculateDuration - Función para calcular duración en minutos
   * @returns {Object} Objeto trip en formato frontend
   */
  const tripFromDatabase = (dbTrip, index, routeId, batchColors, calculateDuration) => {
    return {
      id: dbTrip.id_trip,
      tripNumber: index + 1,
      routeId,
      busId: dbTrip.plate_number || null,
      startTime: dbTrip.start_time.substring(0, 5),  // "08:30:00" → "08:30"
      endTime: dbTrip.end_time.substring(0, 5),
      duration: calculateDuration(dbTrip.start_time, dbTrip.end_time),
      status: _statusLabel(dbTrip.status_trip, dbTrip.plate_number),
      status_trip: dbTrip.status_trip,
      isDragOver: false,
      batch: 'LOTE 1',  // TODO: calcular desde horarios
      batchColor: batchColors[0].color,
      batchIcon: batchColors[0].icon,
      batchNumber: 1,
      isEditing: false,
      editingField: null,
      tempStartTime: null,
      tempEndTime: null,
      fromDatabase: true,
      modified: false
    }
  }

  /**
   * Crea un nuevo objeto trip desde cero, calculando los tiempos relativos
   * a los viajes vecinos.
   *
   * @param {Object}   templateTrip  - Viaje de referencia (toma batch, routeId, duration)
   * @param {Object|null} previousTrip - Viaje anterior en la lista
   * @param {Object|null} nextTrip     - Viaje siguiente en la lista
   * @param {string}   position        - 'after' | 'before'
   * @param {Object}   helpers         - { nextId, timeToMinutes, minutesToTime, calculateDuration }
   * @returns {Object} Objeto trip nuevo en formato frontend
   */
  const createNewTrip = (templateTrip, previousTrip = null, nextTrip = null, position = 'after', helpers = {}) => {
    const { nextId, timeToMinutes, minutesToTime, calculateDuration } = helpers

    let newStartTime, newEndTime
    const newDurationTarget = templateTrip.duration

    if (position === 'after' && previousTrip) {
      // Hora inicial = inicio del anterior + 1 minuto
      const prevStartMinutes = timeToMinutes(previousTrip.startTime)
      const newStartMinutes = prevStartMinutes + 1
      const newEndMinutes   = newStartMinutes + newDurationTarget

      newStartTime = minutesToTime(newStartMinutes)
      newEndTime   = minutesToTime(newEndMinutes)

    } else if (position === 'before' && nextTrip) {
      const nextStartMinutes = timeToMinutes(nextTrip.startTime)
      let newStartMinutes    = nextStartMinutes - newDurationTarget - 1
      let newEndMinutes      = newStartMinutes  + newDurationTarget

      // Ajustar si se solapa con el viaje anterior
      if (previousTrip) {
        const prevEndMinutes = timeToMinutes(previousTrip.endTime)
        if (newStartMinutes < prevEndMinutes + 1) {
          newStartMinutes = prevEndMinutes + 1
          const adjustedDuration = Math.max(15, nextStartMinutes - newStartMinutes - 1)
          newEndMinutes = newStartMinutes + adjustedDuration
        }
      }

      newStartTime = minutesToTime(newStartMinutes)
      newEndTime   = minutesToTime(newEndMinutes)

    } else {
      // Fallback: 30 minutos después del viaje de referencia
      if (previousTrip) {
        const prevEndMinutes  = timeToMinutes(previousTrip.endTime)
        const newStartMinutes = prevEndMinutes + 1
        const newEndMinutes   = newStartMinutes + newDurationTarget
        newStartTime = minutesToTime(newStartMinutes)
        newEndTime   = minutesToTime(newEndMinutes)
      } else {
        const [startH, startM] = templateTrip.startTime.split(':').map(Number)
        const d1 = new Date()
        d1.setHours(startH, startM + 30, 0, 0)
        newStartTime = d1.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: false })

        const d2 = new Date()
        d2.setHours(startH, startM + 30 + newDurationTarget, 0, 0)
        newEndTime = d2.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: false })
      }
    }

    return {
      id: nextId,
      tripNumber: nextId,          // Se recalculará con renumberTrips()
      routeId: templateTrip.routeId,
      busId: null,
      startTime: newStartTime,
      endTime: newEndTime,
      duration: calculateDuration(newStartTime, newEndTime),
      status: 'No Asignado',
      status_trip: null,
      isDragOver: false,
      batch: templateTrip.batch,
      batchColor: templateTrip.batchColor,
      batchIcon: templateTrip.batchIcon,
      batchNumber: templateTrip.batchNumber,
      isEditing: false,
      editingField: null,
      tempStartTime: null,
      tempEndTime: null,
      fromDatabase: false,
      modified: false
    }
  }

  // ─── Helpers privados ────────────────────────────────────────────────────────

  const _statusLabel = (statusCode, plateNumber) => {
    if (statusCode === 3) return 'Activo'
    if (statusCode === 4) return 'Completado'
    if (statusCode === 5) return 'Cancelado'
    return plateNumber ? 'Asignado' : 'No Asignado'
  }

  return {
    tripFromDatabase,
    createNewTrip
  }
}
