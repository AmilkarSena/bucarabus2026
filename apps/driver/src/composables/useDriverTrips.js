import { ref } from 'vue'
import apiClient from '@shared/api/client'
import { extractRouteCoordinates } from '@shared/utils/extractRouteCoordinates'

export function useDriverTrips() {
  const driver = ref({
    id: null,
    id_driver: null,
    name: '',
    cedula: '',
    busId: null,
    busPlate: '',
    ambCode: null,
    routeId: null
  })
  
  const assignedTrips = ref([])
  const currentTrip = ref(null)
  const isRoutesExpanded = ref(false)
  
  // Estado aislado para el calendario semanal
  const calendarTrips = ref([])
  const calendarLoading = ref(false)
  const weeklyTripsCount = ref({})

  const toggleRoutesExpansion = () => {
    isRoutesExpanded.value = !isRoutesExpanded.value
  }

  const loadDriverData = async (userId, authStore) => {
    try {
      const response = await apiClient.get('/drivers')
      const data = response.data
      
      if (data.success) {
        const foundDriver = data.data.find(d => d.id_user === userId)
        if (foundDriver) {
          driver.value.id = foundDriver.id_user
          driver.value.id_driver = foundDriver.id_driver
          driver.value.name = foundDriver.name_driver
          driver.value.cedula = foundDriver.id_driver
          
          await loadTodayTrips()
          return true
        } else {
          console.error('❌ No se encontró información del conductor en /api/drivers')
        }
      }
      return false
    } catch (error) {
      console.error('❌ Error inicializando conductor:', error)
      return false
    }
  }

  const loadTodayTrips = async () => {
    try {
      // 1. Buscar bus asignado
      const busResponse = await apiClient.get('/buses')
      const busData = busResponse.data
      
      if (busData.success) {
        const assignedBus = busData.data.find(b => b.assigned_driver === driver.value.id_driver && b.is_active)
        if (assignedBus) {
          driver.value.busId = assignedBus.plate_number
          driver.value.busPlate = assignedBus.plate_number
          driver.value.ambCode = assignedBus.amb_code || null
        } else {
          console.warn('⚠️ No hay bus asignado al conductor')
          return
        }
      }

      // 2. Obtener viajes para hoy
      const now = new Date()
      const year = now.getFullYear()
      const month = String(now.getMonth() + 1).padStart(2, '0')
      const day = String(now.getDate()).padStart(2, '0')
      const today = `${year}-${month}-${day}`
      
      const tripsResponse = await apiClient.get(`/trips?plate_number=${driver.value.busPlate}&trip_date=${today}`)
      const tripsData = tripsResponse.data
      
      if (tripsData.success && Array.isArray(tripsData.data) && tripsData.data.length > 0) {
        const tripsArray = tripsData.data
        
        assignedTrips.value = await Promise.all(
          tripsArray.map(async (trip) => {
            let routePath = extractRouteCoordinates(trip)
            
            // Si el trip no traía la geometría, la buscamos por ID de ruta
            if (routePath.length === 0) {
              try {
                const routeRes = await apiClient.get(`/routes/${trip.id_route}`)
                if (routeRes.status === 200) {
                  routePath = extractRouteCoordinates(routeRes.data)
                }
              } catch (error) {
                console.warn(`⚠️ Error obteniendo ruta ${trip.id_route}:`, error.message)
              }
            }
            
            return {
              id_trip: trip.id_trip,
              id_route: trip.id_route,
              name: trip.name_route || `Ruta ${trip.id_route}`,
              color: trip.color_route || '#667eea',
              start_time: trip.start_time,
              end_time: trip.end_time,
              status_trip: trip.status_trip,
              trip_date: trip.trip_date,
              path: routePath
            }
          })
        )
        
        // Ordenar por hora de inicio
        assignedTrips.value.sort((a, b) => a.start_time.localeCompare(b.start_time))
        updateCurrentTrip()
        // Actualizar caché de hoy por si el conductor pierde conexión
        localStorage.setItem(`driver_trips_${today}`, JSON.stringify(assignedTrips.value))
      }
    } catch (error) {
      console.error('Error loading today trips:', error)
      // Fallback a caché
      const now = new Date()
      const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`
      const cached = localStorage.getItem(`driver_trips_${todayStr}`)
      if (cached) {
        assignedTrips.value = JSON.parse(cached)
        updateCurrentTrip()
      }
    }
  }

  const loadCalendarTrips = async (dateStr) => {
    if (!driver.value.busPlate) return

    calendarLoading.value = true
    const cacheKey = `driver_trips_${dateStr}`
    
    // 1. Mostrar caché inmediatamente si existe (Offline-First / Stale-While-Revalidate)
    const cachedData = localStorage.getItem(cacheKey)
    if (cachedData) {
      calendarTrips.value = JSON.parse(cachedData)
      calendarLoading.value = false // Ya tenemos datos para mostrar
    } else {
      calendarTrips.value = []
    }

    // 2. Buscar actualizaciones en segundo plano si hay red
    try {
      const tripsResponse = await apiClient.get(`/trips?plate_number=${driver.value.busPlate}&trip_date=${dateStr}`)
      const tripsData = tripsResponse.data
      
      if (tripsData.success && Array.isArray(tripsData.data)) {
        const tripsArray = tripsData.data
        
        const processedTrips = await Promise.all(
          tripsArray.map(async (trip) => {
            let routePath = extractRouteCoordinates(trip)
            if (routePath.length === 0) {
              try {
                const routeRes = await apiClient.get(`/routes/${trip.id_route}`)
                if (routeRes.status === 200) {
                  routePath = extractRouteCoordinates(routeRes.data)
                }
              } catch (e) {}
            }
            return {
              id_trip: trip.id_trip,
              id_route: trip.id_route,
              name: trip.name_route || `Ruta ${trip.id_route}`,
              color: trip.color_route || '#667eea',
              start_time: trip.start_time,
              end_time: trip.end_time,
              status_trip: trip.status_trip,
              trip_date: trip.trip_date,
              path: routePath
            }
          })
        )
        
        processedTrips.sort((a, b) => a.start_time.localeCompare(b.start_time))
        calendarTrips.value = processedTrips
        weeklyTripsCount.value[dateStr] = processedTrips.length
        localStorage.setItem(cacheKey, JSON.stringify(processedTrips))
      } else {
        calendarTrips.value = []
        weeklyTripsCount.value[dateStr] = 0
        localStorage.removeItem(cacheKey)
      }
    } catch (error) {
      console.warn(`No se pudieron obtener actualizaciones para ${dateStr}. Usando caché si existe.`, error)
      if (!cachedData) {
        calendarTrips.value = []
        weeklyTripsCount.value[dateStr] = 0
      }
    } finally {
      calendarLoading.value = false
    }
  }

  // Descarga y cachea la semana entera en segundo plano para los badges
  const loadCalendarWeek = async (weekStartStr) => {
    if (!driver.value?.busPlate) return

    const parts = weekStartStr.split('-')
    const startDate = new Date(parts[0], parts[1] - 1, parts[2])
    const daysToFetch = []
    
    for (let i = 0; i < 7; i++) {
      const d = new Date(startDate)
      d.setDate(d.getDate() + i)
      const y = d.getFullYear()
      const m = String(d.getMonth() + 1).padStart(2, '0')
      const day = String(d.getDate()).padStart(2, '0')
      daysToFetch.push(`${y}-${m}-${day}`)
    }

    // Poblar recuentos desde caché primero (respuesta instantánea)
    const newCounts = { ...weeklyTripsCount.value }
    daysToFetch.forEach(dateStr => {
      const cached = localStorage.getItem(`driver_trips_${dateStr}`)
      if (cached) {
        newCounts[dateStr] = JSON.parse(cached).length
      } else if (newCounts[dateStr] === undefined) {
        newCounts[dateStr] = 0
      }
    })
    weeklyTripsCount.value = newCounts

    // Fetch silencioso en paralelo
    Promise.all(daysToFetch.map(async (dateStr) => {
      try {
        const cacheKey = `driver_trips_${dateStr}`
        const res = await apiClient.get(`/trips?plate_number=${driver.value.busPlate}&trip_date=${dateStr}`)
        
        if (res.data.success && Array.isArray(res.data.data)) {
          const tripsArray = res.data.data
          weeklyTripsCount.value = { ...weeklyTripsCount.value, [dateStr]: tripsArray.length }
          
          // Opcional: Procesamos y cacheamos para que si el usuario hace click, sea instantáneo
          const processedTrips = await Promise.all(tripsArray.map(async (trip) => {
            let routePath = extractRouteCoordinates(trip)
            if (routePath.length === 0) {
              try {
                const rRes = await apiClient.get(`/routes/${trip.id_route}`)
                if (rRes.status === 200) routePath = extractRouteCoordinates(rRes.data)
              } catch (e) {}
            }
            return {
              id_trip: trip.id_trip, id_route: trip.id_route,
              name: trip.name_route || `Ruta ${trip.id_route}`,
              color: trip.color_route || '#667eea',
              start_time: trip.start_time, end_time: trip.end_time,
              status_trip: trip.status_trip, trip_date: trip.trip_date, path: routePath
            }
          }))
          processedTrips.sort((a, b) => a.start_time.localeCompare(b.start_time))
          localStorage.setItem(cacheKey, JSON.stringify(processedTrips))
          
          // Si el día procesado en background es el seleccionado actualmente, actualizamos la vista
          const selectedCached = localStorage.getItem(`driver_trips_${calendarTrips.value?.[0]?.trip_date}`)
          if (calendarTrips.value.length > 0 && calendarTrips.value[0].trip_date === dateStr) {
             calendarTrips.value = processedTrips
          }
        }
      } catch (error) {
        // Ignorar errores en background
      }
    }))
  }

  const updateCurrentTrip = () => {
    if (assignedTrips.value.length === 0) return
    
    const now = new Date()
    const currentTime = now.toTimeString().slice(0, 8)
    
    let foundTrip = assignedTrips.value.find(t => 
      t.status_trip === 3 || (t.start_time <= currentTime && t.end_time >= currentTime)
    )
    
    if (!foundTrip) {
      foundTrip = assignedTrips.value.find(t => t.start_time > currentTime && t.status_trip === 1)
    }
    
    if (!foundTrip) {
      foundTrip = assignedTrips.value[assignedTrips.value.length - 1]
    }
    
    if (foundTrip && foundTrip.id_trip !== currentTrip.value?.id_trip) {
      currentTrip.value = foundTrip
      driver.value.routeId = foundTrip.id_route
    } else if (!currentTrip.value && foundTrip) {
      currentTrip.value = foundTrip
      driver.value.routeId = foundTrip.id_route
    }
  }

  const selectTrip = (trip) => {
    if (trip.status_trip === 4) return // No permitir seleccionar viajes completados
    currentTrip.value = trip
    driver.value.routeId = trip.id_route
    isRoutesExpanded.value = false
  }

  const updateTripStatus = async (statusId) => {
    if (!currentTrip.value) return false
    try {
      await apiClient.put(`/trips/${currentTrip.value.id_trip}`, { status_trip: statusId })
      currentTrip.value.status_trip = statusId
      
      // Actualizar en el array principal
      const idx = assignedTrips.value.findIndex(t => t.id_trip === currentTrip.value.id_trip)
      if (idx !== -1) assignedTrips.value[idx].status_trip = statusId
      
      return true
    } catch (error) {
      console.error('Error actualizando estado del viaje:', error)
      return false
    }
  }

  return {
    driver,
    assignedTrips,
    currentTrip,
    isRoutesExpanded,
    calendarTrips,
    calendarLoading,
    weeklyTripsCount,
    loadDriverData,
    loadCalendarTrips,
    loadCalendarWeek,
    updateCurrentTrip,
    selectTrip,
    toggleRoutesExpansion,
    updateTripStatus
  }
}
