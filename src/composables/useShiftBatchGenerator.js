// src/composables/useShiftBatchGenerator.js

/**
 * Composable que encapsula la lógica de generación algorítmica de viajes en lote (Batches).
 * 
 * Este módulo automatiza la creación masiva de cronogramas para una ruta:
 * 1. Generación Secuencial: Calcula horas de inicio y fin basándose en una frecuencia y duración dadas.
 * 2. Gestión de Lotes: Asocia los viajes creados a un "Lote" específico con colores e iconos únicos 
 *    para diferenciarlos visualmente en la cuadrícula de despachos.
 * 3. Continuidad de Datos: Asegura que los nuevos viajes mantengan la secuencia de IDs y números de viaje 
 *    existentes para evitar colisiones de datos en el frontend.
 * 
 * @returns {Object} { batchColors, getNextBatchNumber, generateTripsBatch }
 */
export function useShiftBatchGenerator() {
  // Configuración de colores para los lotes, tal cual estaba en ShiftsModal
  const batchColors = [
    { color: '#dbeafe', icon: '🔵' },
    { color: '#fef3c7', icon: '🟡' },
    { color: '#d1fae5', icon: '🟢' },
    { color: '#fce7f3', icon: '🔴' },
    { color: '#e0e7ff', icon: '🟣' },
    { color: '#fed7aa', icon: '🟠' },
    { color: '#e9d5ff', icon: '🟣' },
    { color: '#ccfbf1', icon: '🔷' },
  ]

  /**
   * Obtiene el próximo número de lote (batch) para una ruta específica.
   */
  const getNextBatchNumber = (existingTrips, routeId) => {
    const existingBatches = existingTrips
      .filter(trip => trip.routeId === routeId)
      .map(trip => trip.batchNumber || 0) // Fallback a 0 por si hay viajes sin batch

    if (existingBatches.length === 0) {
      return 1
    }

    return Math.max(...existingBatches) + 1
  }

  /**
   * Genera el arreglo de nuevos viajes basándose en los parámetros de entrada.
   * Retorna los viajes nuevos y un mensaje de estado.
   * No muta el estado global; retorna los datos para que el orquestador los aplique.
   */
  const generateTripsBatch = (params) => {
    const {
      routeId,
      startTimeStr,
      endTimeStr,
      frequency,
      duration,
      existingTrips
    } = params

    const timeRegex = /^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$/
    if (!timeRegex.test(startTimeStr) || !timeRegex.test(endTimeStr)) {
      return { success: false, msg: 'Formato de hora inválido. Usa HH:mm (ejemplo: 08:30)' }
    }

    const [startH, startM] = startTimeStr.split(':').map(Number)
    const [endH, endM] = endTimeStr.split(':').map(Number)

    let currentTime = new Date()
    currentTime.setHours(startH, startM, 0, 0)

    const operationEndTime = new Date()
    operationEndTime.setHours(endH, endM, 0, 0)

    if (operationEndTime <= currentTime) {
      return { success: false, msg: 'La hora de fin debe ser posterior a la hora de inicio.' }
    }

    const nextBatchNumber = getNextBatchNumber(existingTrips, routeId)
    const newTrips = []

    // Encontrar el ID más alto actual para continuar la secuencia
    const maxId = existingTrips.length > 0
      ? Math.max(...existingTrips.map(trip => trip.id))
      : 0
    let tripCount = maxId

    const colorIndex = (nextBatchNumber - 1) % batchColors.length
    const batchColor = batchColors[colorIndex]

    while (currentTime <= operationEndTime) {
      const tripStartTime = new Date(currentTime)
      const tripEndTime = new Date(tripStartTime.getTime() + duration * 60000)

      // Número secuencial que continúa desde el lote anterior
      tripCount++
      const sequentialNumber = tripCount

      newTrips.push({
        id: sequentialNumber,
        tripNumber: sequentialNumber,
        routeId: routeId,
        busId: null,
        startTime: tripStartTime.toLocaleTimeString('es-CO', {hour: '2-digit', minute:'2-digit', hour12: false}),
        endTime: tripEndTime.toLocaleTimeString('es-CO', {hour: '2-digit', minute:'2-digit', hour12: false}),
        duration: duration,
        status: 'No Asignado',
        isDragOver: false,
        batch: `LOTE ${nextBatchNumber}`,
        batchColor: batchColor.color,
        batchIcon: batchColor.icon,
        batchNumber: nextBatchNumber,
        // Propiedades para edición inline
        isEditing: false,
        editingField: null,
        tempStartTime: null,
        tempEndTime: null,
        // Indicar que es nuevo (no viene de BD)
        fromDatabase: false,
        modified: false
      })

      currentTime.setMinutes(currentTime.getMinutes() + frequency)
    }

    return { 
      success: true, 
      data: newTrips, 
      msg: `Se creó el Lote ${nextBatchNumber} con ${newTrips.length} viajes.` 
    }
  }

  return {
    batchColors,
    getNextBatchNumber,
    generateTripsBatch
  }
}
