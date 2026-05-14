const handleSaveTime = (tripId, field, newTime) => {
  const timeRegex = /^([0-1]?[0-9]|2[0-3]):([0-5][0-9])$/

  if (!timeRegex.test(newTime)) {
    alert('❌ Formato de hora inválido. Usa HH:mm')
    return
  }

  // Buscar el viaje en el array original
  const tripIndex = trips.value.findIndex(t => t.id === tripId)
  if (tripIndex === -1) {
    console.error('❌ No se encontró el viaje')
    return
  }

  // Validaciones de orden para hora inicio
  if (field === 'start') {
    const currentTrips = filteredTrips.value
    const filteredIndex = currentTrips.findIndex(t => t.id === tripId)
    const newStartMinutes = timeToMinutes(newTime)

    // Validar con el viaje anterior
    if (filteredIndex > 0) {
      const prevTrip = currentTrips[filteredIndex - 1]
      if (newStartMinutes <= timeToMinutes(prevTrip.startTime)) {
        alert(`❌ La hora inicial debe ser mayor a la del viaje anterior (${prevTrip.startTime})`)
        return
      }
    }

    // Validar con el viaje siguiente
    if (filteredIndex < currentTrips.length - 1) {
      const nextTrip = currentTrips[filteredIndex + 1]
      if (newStartMinutes >= timeToMinutes(nextTrip.startTime)) {
        alert(`❌ La hora inicial debe ser menor a la del viaje siguiente (${nextTrip.startTime})`)
        return
      }
    }

    // Validar que hora inicio sea menor que hora fin actual
    const currentEndTime = trips.value[tripIndex].endTime
    const endMinutes = timeToMinutes(currentEndTime)
    if (newStartMinutes >= endMinutes) {
      alert(`❌ La hora de inicio (${newTime}) debe ser menor que la hora de fin (${currentEndTime})`)
      return
    }

    // Actualizar
    trips.value[tripIndex].startTime = newTime
    trips.value[tripIndex].duration = calculateDuration(newTime, trips.value[tripIndex].endTime)
    if (trips.value[tripIndex].fromDatabase) {
      trips.value[tripIndex].modified = true
    }
    console.log(`✅ Hora inicio actualizada: ${newTime}`)

  } else if (field === 'end') {
    // Validar que hora fin sea mayor que hora inicio
    const currentStartTime = trips.value[tripIndex].startTime
    const newEndMinutes = timeToMinutes(newTime)
    const startMinutes = timeToMinutes(currentStartTime)

    if (newEndMinutes <= startMinutes) {
      alert(`❌ La hora de fin (${newTime}) debe ser mayor que la hora de inicio (${currentStartTime})`)
      return
    }

    // Validar con la hora de inicio del siguiente viaje (para no pisarlo)
    const currentTrips = filteredTrips.value
    const filteredIndex = currentTrips.findIndex(t => t.id === tripId)
    
    if (filteredIndex < currentTrips.length - 1) {
      const nextTrip = currentTrips[filteredIndex + 1]
      if (newEndMinutes >= timeToMinutes(nextTrip.startTime)) {
        alert(`❌ La hora de fin (${newTime}) debe ser menor que la hora de inicio del viaje siguiente (${nextTrip.startTime})`)
        return
      }
    }

    // Actualizar
    trips.value[tripIndex].endTime = newTime
    trips.value[tripIndex].duration = calculateDuration(trips.value[tripIndex].startTime, newTime)
    if (trips.value[tripIndex].fromDatabase) {
      trips.value[tripIndex].modified = true
    }
    console.log(`✅ Hora fin actualizada: ${newTime}`)
  }
}
