// src/composables/useShiftPersistence.js

/**
 * Composable especializado en la persistencia atómica de la programación de despachos.
 * 
 * Actúa como la capa de persistencia (I/O) para el sistema de turnos:
 * 1. Guardado en Cascada: Orquesta el guardado de múltiples cambios en un solo flujo lógico:
 *    - Sincroniza viajes modificados (PUT).
 *    - Cancela viajes eliminados (POST /cancel).
 *    - Crea nuevos bloques de viajes (POST /batch).
 * 2. Mapeo de Identidades: Traduce las placas de buses (frontend) a IDs de base de datos internos.
 * 3. Gestión de Errores Granular: Recolecta errores individuales por viaje para permitir 
 *    una retroalimentación detallada al usuario en caso de fallos parciales.
 * 4. Invalidation de Caché: Asegura que el Store de turnos se refresque tras cada operación exitosa.
 */
import { ref } from 'vue'
import { updateTrip, cancelTrip as cancelTripAPI } from '../api/trips'
import { SYSTEM_USER_ID } from '../constants/system'

export function useShiftPersistence(tripsStore) {

  const isSaving = ref(false)
  const saveError = ref(null)

  /**
   * Guarda el estado actual de los viajes en la base de datos.
   * Maneja 3 operaciones en secuencia: actualizar modificados, cancelar eliminados, crear nuevos.
   *
   * @param {Object} params
   * @param {Array}  params.filteredTrips   - Viajes visibles en pantalla (ya filtrados por ruta)
   * @param {Array}  params.deletedTripIds  - IDs de viajes eliminados pendientes de cancelar
   * @param {string|number} params.routeId  - ID de la ruta
   * @param {string} params.tripDate        - Fecha en formato YYYY-MM-DD
   * @param {Object} params.busesStore      - Store de buses (para obtener id_bus desde plate_number)
   *
   * @returns {Promise<{success: boolean, updatedCount: number, createdCount: number, deletedCount: number, errors: string[]}>}
   */
  const saveSchedule = async ({ filteredTrips, deletedTripIds, routeId, tripDate, busesStore }) => {
    isSaving.value = true
    saveError.value = null

    let updatedCount = 0
    let createdCount = 0
    let deletedCount = 0
    const errors = []

    try {
      const modifiedTrips = filteredTrips.filter(t => t.fromDatabase && t.modified)
      const newTrips      = filteredTrips.filter(t => !t.fromDatabase)
      const deletedIds    = [...deletedTripIds]

      // ── 1. Actualizar viajes modificados ────────────────────────────────────
      for (const trip of modifiedTrips) {
        try {
          const bus      = trip.busId ? busesStore.buses.find(b => b.plate_number === trip.busId) : null
          const id_bus   = bus ? bus.id_bus    : 0
          const id_driver = bus ? (bus.assigned_driver || 0) : 0
          const id_status = trip.busId ? 2 : 1   // 2=assigned, 1=pending

          const updateData = {
            start_time:  trip.startTime + ':00',
            end_time:    trip.endTime   + ':00',
            id_bus,
            id_driver,
            id_status,
            user_update: SYSTEM_USER_ID
          }

          const result = await updateTrip(trip.id, updateData)

          if (result.success) {
            updatedCount++
          } else {
            errors.push(`Viaje ${trip.tripNumber}: ${result.msg}`)
          }
        } catch (error) {
          const msg = error.response?.data?.msg || error.message
          errors.push(`Viaje ${trip.tripNumber}: ${msg}`)
        }
      }

      // ── 2. Cancelar viajes marcados para eliminación (legacy / pendientes) ──
      for (const tripData of deletedIds) {
        let tripId = null
        try {
          tripId = typeof tripData === 'object' ? tripData.id : tripData
          const options = typeof tripData === 'object'
            ? { cancellation_reason: tripData.cancellation_reason, force_cancel: tripData.force_cancel || false }
            : { cancellation_reason: 'Viaje cancelado desde interfaz' }

          const result = await cancelTripAPI(tripId, options)
          if (result.success) {
            deletedCount++
          } else {
            errors.push(`Cancelación de viaje ${tripId}: ${result.msg}`)
          }
        } catch (error) {
          const msg = error.response?.data?.msg || error.message
          errors.push(`Error cancelando viaje ${tripId || 'desconocido'}: ${msg}`)
        }
      }

      // ── 3. Crear viajes nuevos ───────────────────────────────────────────────
      if (newTrips.length > 0) {
        const tripsToCreate = newTrips.map(trip => {
          const bus = trip.busId ? busesStore.buses.find(b => b.plate_number === trip.busId) : null
          return {
            start_time: trip.startTime + ':00',
            end_time:   trip.endTime   + ':00',
            id_bus:     bus?.id_bus          || null,
            id_driver:  bus?.assigned_driver  || null,
            id_status:  trip.busId ? 2 : 1
          }
        })

        const result = await tripsStore.createTripsBatch({
          id_route:    routeId,
          trip_date:   tripDate,
          trips:       tripsToCreate,
          user_create: SYSTEM_USER_ID
        })

        if (result.success) {
          createdCount = result.trips_created || newTrips.length
        } else {
          errors.push(result.msg)
        }
      }

      // Invalidar caché siempre (éxito o errores parciales)
      tripsStore.invalidateCache(routeId, tripDate)

      return {
        success: errors.length === 0,
        updatedCount,
        createdCount,
        deletedCount,
        errors
      }

    } catch (fatalError) {
      const msg = fatalError.message || 'Error desconocido al guardar'
      saveError.value = msg
      return { success: false, updatedCount, createdCount, deletedCount, errors: [msg] }
    } finally {
      isSaving.value = false
    }
  }

  /**
   * Cancela un viaje en la base de datos inmediatamente.
   * Los diálogos de confirmación (confirm/prompt) son responsabilidad del componente llamador.
   *
   * @param {number|string} tripId
   * @param {Object} options - { force_cancel: boolean, cancellation_reason: string }
   * @returns {Promise<{success: boolean, msg: string}>}
   */
  const cancelTripImmediate = async (tripId, options = {}) => {
    try {
      const result = await cancelTripAPI(tripId, {
        force_cancel: options.force_cancel || false,
        cancellation_reason: options.cancellation_reason || 'Viaje cancelado desde interfaz'
      })
      return { success: result.success, msg: result.msg || '' }
    } catch (error) {
      const msg = error.response?.data?.msg || error.message
      return { success: false, msg }
    }
  }

  return {
    isSaving,
    saveError,
    saveSchedule,
    cancelTripImmediate
  }
}
