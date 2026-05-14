/**
 * Composable que centraliza la lógica de manipulación y validación de la lista de viajes (CRUD en memoria).
 * 
 * Responsabilidades:
 * 1. Manipulación de Horarios: Cambiar hora inicio/fin con validación estricta de solapamientos.
 * 2. Inserción de Viajes: Agregar viajes individuales o insertar entre dos existentes.
 * 3. Eliminación Segura: Borrar viajes con confirmación especial si están "En Curso" (cancelación en BD).
 * 4. Desasignación: Liberar un bus de un viaje específico.
 * 5. Secuenciación: Mantener los números de viaje visuales actualizados.
 */

export function useShiftsManager({
  trips,
  filteredTrips,
  selectedRouteId,
  selectedDate,
  isPastDate,
  batchColors,
  getNextBatchNumber,
  buildNewTrip,
  timeToMinutes,
  minutesToTime,
  calculateDuration,
  setBusAvailability,
  cancelTripImmediate,
  tripsStore
}) {

  // ─── Utilidades ───

  // Renumerar los tripNumber para mantener secuencia visual continua
  const renumberTrips = () => {
    trips.value.forEach((trip, index) => {
      trip.tripNumber = index + 1
    })
  }

  // Obtener frecuencia respecto al viaje anterior
  const getFrequencyFromPrevious = (trip) => {
    const tripIndex = filteredTrips.value.findIndex(t => t.id === trip.id)
    if (tripIndex <= 0) return '-'
    const prevTrip = filteredTrips.value[tripIndex - 1]
    const currentMinutes = timeToMinutes(trip.startTime)
    const prevMinutes = timeToMinutes(prevTrip.startTime)
    const frequency = currentMinutes - prevMinutes
    return `${frequency > 0 ? '+' : ''}${frequency} min`
  }

  // ─── Manipulación de Asignación ───

  const unassignBus = (trip) => {
    if (isPastDate.value) return
    if (trip.status_trip === 3 || trip.status_trip === 4) return
    console.log('🔍 unassignBus llamado con:', { tripId: trip.id, busId: trip.busId })
    
    const originalTrip = trips.value.find(t => t.id === trip.id)
    if (originalTrip && originalTrip.busId) {
      const oldBusId = originalTrip.busId
      originalTrip.busId = null
      originalTrip.status = 'No Asignado'
      if (originalTrip.fromDatabase) {
        originalTrip.modified = true
      }
      console.log(`🚌 Bus ${oldBusId} desasignado del viaje ${trip.id}`)
    }
  }

  // ─── Edición de Tiempos ───

  const handleSaveTime = (tripId, field, newTime) => {
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$/
    if (!timeRegex.test(newTime)) {
      alert('❌ Formato de hora inválido. Usa HH:mm')
      return
    }

    const tripIndex = trips.value.findIndex(t => t.id === tripId)
    if (tripIndex === -1) return

    if (field === 'start') {
      const currentTrips = filteredTrips.value
      const filteredIndex = currentTrips.findIndex(t => t.id === tripId)
      const newStartMinutes = timeToMinutes(newTime)

      if (filteredIndex > 0) {
        const prevTrip = currentTrips[filteredIndex - 1]
        if (newStartMinutes <= timeToMinutes(prevTrip.startTime)) {
          alert(`❌ La hora inicial debe ser mayor a la del viaje anterior (${prevTrip.startTime})`)
          return
        }
      }

      if (filteredIndex < currentTrips.length - 1) {
        const nextTrip = currentTrips[filteredIndex + 1]
        if (newStartMinutes >= timeToMinutes(nextTrip.startTime)) {
          alert(`❌ La hora inicial debe ser menor a la del viaje siguiente (${nextTrip.startTime})`)
          return
        }
      }

      const endMinutes = timeToMinutes(trips.value[tripIndex].endTime)
      if (newStartMinutes >= endMinutes) {
        alert(`❌ La hora de inicio (${newTime}) debe ser menor que la hora de fin (${trips.value[tripIndex].endTime})`)
        return
      }

      trips.value[tripIndex].startTime = newTime
      trips.value[tripIndex].duration = calculateDuration(newTime, trips.value[tripIndex].endTime)
      if (trips.value[tripIndex].fromDatabase) trips.value[tripIndex].modified = true

    } else if (field === 'end') {
      const startMinutes = timeToMinutes(trips.value[tripIndex].startTime)
      const newEndMinutes = timeToMinutes(newTime)

      if (newEndMinutes <= startMinutes) {
        alert(`❌ La hora de fin (${newTime}) debe ser mayor que la hora de inicio (${trips.value[tripIndex].startTime})`)
        return
      }

      const currentTrips = filteredTrips.value
      const filteredIndex = currentTrips.findIndex(t => t.id === tripId)
      
      if (filteredIndex < currentTrips.length - 1) {
        const nextTrip = currentTrips[filteredIndex + 1]
        if (newEndMinutes >= timeToMinutes(nextTrip.startTime)) {
          alert(`❌ La hora de fin (${newTime}) debe ser menor que la hora de inicio del viaje siguiente (${nextTrip.startTime})`)
          return
        }
      }

      trips.value[tripIndex].endTime = newTime
      trips.value[tripIndex].duration = calculateDuration(trips.value[tripIndex].startTime, newTime)
      if (trips.value[tripIndex].fromDatabase) trips.value[tripIndex].modified = true
    }
  }

  // ─── Inserción de Viajes ───

  const handleAddTripConfirm = ({ startTime, endTime }) => {
    const maxId = trips.value.length > 0 ? Math.max(...trips.value.map(t => t.id)) : 0
    const nextBatchNumber = getNextBatchNumber(trips.value, selectedRouteId.value)
    const colorIndex = (nextBatchNumber - 1) % batchColors.length

    const templateTrip = {
      routeId:     selectedRouteId.value,
      duration:    timeToMinutes(endTime) - timeToMinutes(startTime),
      startTime,
      endTime,
      batch:       `LOTE ${nextBatchNumber}`,
      batchColor:  batchColors[colorIndex].color,
      batchIcon:   batchColors[colorIndex].icon,
      batchNumber: nextBatchNumber
    }

    const newTrip = buildNewTrip(templateTrip, null, null, 'after', {
      nextId: maxId + 1,
      timeToMinutes,
      minutesToTime,
      calculateDuration
    })
    
    newTrip.startTime = startTime
    newTrip.endTime   = endTime
    newTrip.duration  = calculateDuration(startTime, endTime)

    trips.value.push(newTrip)
    renumberTrips()
  }

  const insertTripAfter = (referenceTrip) => {
    if (isPastDate.value) return
    const referenceIndex = trips.value.findIndex(t => t.id === referenceTrip.id)
    const nextTrip = referenceIndex < trips.value.length - 1 ? trips.value[referenceIndex + 1] : null

    const newStartMinutes = timeToMinutes(referenceTrip.startTime) + 1

    const isToday = selectedDate.value.toLocaleDateString('en-CA') === new Date().toLocaleDateString('en-CA')
    if (isToday) {
      const now = new Date()
      const currentMinutes = now.getHours() * 60 + now.getMinutes()
      if (newStartMinutes <= currentMinutes) {
        const currentTimeStr = now.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false })
        alert(`❌ No se puede insertar un viaje con hora de inicio (${minutesToTime(newStartMinutes)}) menor o igual a la hora actual (${currentTimeStr}).`)
        return
      }
    }

    if (nextTrip) {
      const nextStartMinutes = timeToMinutes(nextTrip.startTime)
      if (newStartMinutes >= nextStartMinutes) {
        alert(`❌ No hay espacio suficiente.\n\nHora actual: ${referenceTrip.startTime}\nNueva hora: ${minutesToTime(newStartMinutes)}\nHora siguiente: ${nextTrip.startTime}\n\nNecesita al menos 1 minuto entre las horas iniciales.`)
        return
      }
    }
    
    const newTrip = buildNewTrip(referenceTrip, referenceTrip, nextTrip, 'after', {
      nextId: Math.max(...trips.value.map(t => t.id)) + 1,
      timeToMinutes,
      minutesToTime,
      calculateDuration
    })
    
    if (referenceIndex !== -1) {
      trips.value.splice(referenceIndex + 1, 0, newTrip)
      renumberTrips()
    }
  }

  // ─── Eliminación de Viajes ───

  const clearSchedule = () => {
    if (!selectedRouteId.value) return
    const tripsToDelete = trips.value.filter(trip => trip.routeId === selectedRouteId.value)
    if (tripsToDelete.length === 0) return

    if (confirm(`¿Estás seguro de que quieres borrar ${tripsToDelete.length} viajes para esta ruta?`)) {
      trips.value = trips.value.filter(trip => trip.routeId !== selectedRouteId.value)
      alert('Viajes eliminados correctamente.')
    }
  }

  const deleteTrip = async (trip) => {
    if (isPastDate.value) return
    const index = trips.value.findIndex(t => t.id === trip.id)
    if (index !== -1) {
      if (trip.fromDatabase && trip.id) {
        const isActive = trip.status_trip === 3
        let cancellationOptions = {}
        
        if (isActive) {
          const confirmCancel = confirm(
            '⚠️ ADVERTENCIA: Este viaje está ACTIVO (en curso).\n\n' +
            'Cancelar un viaje activo requiere una razón válida y puede afectar a pasajeros.\n\n' +
            '¿Está seguro de que desea cancelarlo?'
          )
          if (!confirmCancel) return
          
          const reason = prompt('Por favor, ingrese la razón de cancelación (mínimo 10 caracteres):', 'Emergencia: ')
          if (!reason || reason.trim().length < 10) {
            alert('❌ Error: La razón de cancelación es obligatoria para viajes activos (mínimo 10 caracteres)')
            return
          }
          cancellationOptions = { force_cancel: true, cancellation_reason: reason.trim() }
        } else {
          const reason = prompt('Razón de cancelación (opcional):', 'Viaje cancelado desde interfaz')
          cancellationOptions = { force_cancel: false, cancellation_reason: reason || 'Viaje cancelado desde interfaz' }
        }
        
        const result = await cancelTripImmediate(trip.id, cancellationOptions)
        
        if (result.success) {
          const tripDate = selectedDate.value.toISOString().split('T')[0]
          tripsStore.invalidateCache(selectedRouteId.value, tripDate)
        } else {
          alert(`❌ Error al cancelar viaje: ${result.msg}`)
          return
        }
      }
      
      if (trip.busId) {
        setBusAvailability(trip.busId, true)
      }
      trips.value.splice(index, 1)
      renumberTrips()
    }
  }

  return {
    unassignBus,
    handleSaveTime,
    getFrequencyFromPrevious,
    handleAddTripConfirm,
    insertTripAfter,
    clearSchedule,
    deleteTrip
  }
}
