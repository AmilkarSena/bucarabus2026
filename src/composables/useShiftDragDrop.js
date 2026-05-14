import { ref } from 'vue'

/**
 * Composable que gestiona la interactividad de asignación de flota mediante Drag and Drop.
 * 
 * Este módulo permite a los despachadores arrastrar buses hacia la cuadrícula de horarios:
 * 1. Control de Estados: Gestiona los estados visuales (dragging, dragover) de las tarjetas y filas.
 * 2. Validación Preventiva: Antes de permitir el "Drop", verifica que el bus no tenga 
 *    conflictos de horario (solapamientos) en la ruta actual o en cualquier otra ruta del día.
 * 3. Integridad Operativa: Impide asignaciones en fechas pasadas o en viajes que ya están en 
 *    progreso o cancelados.
 * 4. Gestión de Cambios: Marca los viajes como "modificados" para permitir un guardado posterior por lotes.
 */
export function useShiftDragDrop({
  trips,
  allDayTrips,
  selectedRouteId,
  isPastDate,
  hasBusOverlap,
  timeToMinutes
}) {
  const draggedBusId = ref(null)

  const handleDragStart = (event, bus) => {
    draggedBusId.value = bus.plate_number
    event.target.classList.add('dragging')
  }

  const handleDragOver = (event, trip) => {
    event.preventDefault()
    if (!trip.busId) {
      trip.isDragOver = true
    }
  }

  const handleDragLeave = (event, trip) => {
    event.preventDefault()
    trip.isDragOver = false
  }

  const handleDrop = (event, trip) => {
    event.preventDefault()
    trip.isDragOver = false

    if (isPastDate.value) return
    if (trip.status_trip === 3 || trip.status_trip === 4) return

    if (draggedBusId.value && !trip.busId) {
      if (hasBusOverlap(draggedBusId.value, trip)) {
        const conflict =
          trips.value.find(t =>
            t.busId === draggedBusId.value && t.status_trip !== 4 && t.status_trip !== 5 &&
            timeToMinutes(t.endTime) > timeToMinutes(trip.startTime) &&
            timeToMinutes(t.startTime) < timeToMinutes(trip.endTime)
          ) ||
          allDayTrips.value.find(t =>
            t.busId === draggedBusId.value && t.status_trip !== 4 && t.status_trip !== 5 &&
            timeToMinutes(t.endTime) > timeToMinutes(trip.startTime) &&
            timeToMinutes(t.startTime) < timeToMinutes(trip.endTime)
          )
        
        const conflictLabel = conflict
          ? `${conflict.startTime}–${conflict.endTime}` + (conflict.routeId && conflict.routeId !== selectedRouteId.value ? ` (otra ruta)` : '')
          : ''
        
        alert(`❌ El bus ya tiene un viaje que se solapa con este horario (${conflictLabel}).`)
        draggedBusId.value = null
        document.querySelectorAll('.bus-card.dragging').forEach(card => card.classList.remove('dragging'))
        return
      }

      const originalTrip = trips.value.find(t => t.id === trip.id)
      if (originalTrip) {
        originalTrip.busId = draggedBusId.value
        originalTrip.status = 'Asignado'
        if (originalTrip.fromDatabase) {
          originalTrip.modified = true
        }
      }
    }

    draggedBusId.value = null
    document.querySelectorAll('.bus-card.dragging').forEach(card => {
      card.classList.remove('dragging')
    })
  }

  return {
    draggedBusId,
    handleDragStart,
    handleDragOver,
    handleDragLeave,
    handleDrop
  }
}
