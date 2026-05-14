// src/composables/useShiftTimeValidation.js

/**
 * Composable especializado en la gestión de tiempos y validación de disponibilidad de flota.
 * 
 * Este módulo centraliza las reglas de negocio críticas para la programación de despachos:
 * 1. Conversión de Formatos: Transforma horas (HH:mm) a minutos totales para cálculos aritméticos precisos.
 * 2. Detección de Conflictos: Verifica en tiempo real si un bus tiene "solapamiento" (overlap).
 *    - Revisa la ruta que el despachador tiene abierta actualmente (incluyendo cambios no guardados).
 *    - Revisa todas las demás rutas del sistema para ese día (datos persistidos en DB).
 * 3. Gestión de Estados de Viaje: Ignora conflictos con viajes que han sido Cancelados (status 4) o Finalizados (status 5).
 * 4. Cálculos de Duración: Determina el tiempo de recorrido entre puntos de control.
 * 
 * @param {Ref<Array>} trips - Referencia reactiva a los viajes de la ruta actual (estado local del modal).
 * @param {Ref<Array>} allDayTrips - Referencia reactiva a la base de datos completa de viajes del día.
 * @returns {Object} Métodos utilitarios para validación de cronogramas.
 */
export function useShiftTimeValidation(trips, allDayTrips) {
  
  /**
   * Convierte un string de hora (ej: "14:30") a minutos totales desde la medianoche (870 min).
   * Esto permite comparar si una hora es mayor que otra usando operadores matemáticos simples (> o <).
   */
  const timeToMinutes = (timeStr) => {
    if (!timeStr) return 0
    const [h, m] = timeStr.split(':').map(Number)
    return h * 60 + m
  }

  /**
   * Realiza la operación inversa: convierte minutos (870) a un string legible (ej: "14:30").
   * Se utiliza principalmente para mostrar resultados en la interfaz de usuario.
   */
  const minutesToTime = (minutes) => {
    const h = Math.floor(minutes / 60)
    const m = minutes % 60
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`
  }

  /**
   * Algoritmo de detección de colisiones de flota.
   * Determina si un bus específico (plateNumber) ya tiene un compromiso en el horario 
   * del viaje que se intenta asignar (targetTrip).
   * 
   * La lógica de solapamiento es: (InicioA < FinB) Y (FinA > InicioB).
   */
  const hasBusOverlap = (plateNumber, targetTrip) => {
    if (!plateNumber || !targetTrip) return false

    const cleanPlate = plateNumber.trim().toUpperCase()

    // 1. Check current route trips (includes new unsaved ones)
    if (trips && trips.value) {
      const conflictInCurrentRoute = trips.value.find(t => {
        if (!t.busId) return false
        return t.busId.trim().toUpperCase() === cleanPlate &&
          t.id !== targetTrip.id &&
          t.status_trip !== 4 && t.status_trip !== 5 &&
          timeToMinutes(t.endTime) > timeToMinutes(targetTrip.startTime) &&
          timeToMinutes(t.startTime) < timeToMinutes(targetTrip.endTime)
      })

      if (conflictInCurrentRoute) {
        console.warn(`Conflicto en ruta actual con viaje ${conflictInCurrentRoute.id}`)
        return true
      }
    }

    // 2. Check other routes' trips from DB
    if (allDayTrips && allDayTrips.value) {
      const conflictInOtherRoutes = allDayTrips.value.find(t => {
        if (!t.busId) return false
        return t.busId.trim().toUpperCase() === cleanPlate &&
          t.status_trip !== 4 && t.status_trip !== 5 &&
          timeToMinutes(t.endTime) > timeToMinutes(targetTrip.startTime) &&
          timeToMinutes(t.startTime) < timeToMinutes(targetTrip.endTime)
      })

      if (conflictInOtherRoutes) {
        console.warn(`Conflicto en OTRA ruta con viaje ${conflictInOtherRoutes.id} (${conflictInOtherRoutes.startTime}-${conflictInOtherRoutes.endTime})`)
        return true
      }
    }

    return false
  }

  /**
   * Calcula la diferencia de tiempo neta en minutos entre dos marcas de tiempo.
   * Útil para validar que la duración del viaje sea coherente con la distancia de la ruta.
   */
  const calculateDuration = (startTime, endTime) => {
    if (!startTime || !endTime) return 0
    return timeToMinutes(endTime.substring(0, 5)) - timeToMinutes(startTime.substring(0, 5))
  }

  return {
    timeToMinutes,
    minutesToTime,
    hasBusOverlap,
    calculateDuration
  }
}
