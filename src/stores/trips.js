import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as tripsApi from '../api/trips'

export const useTripsStore = defineStore('trips', () => {
  // Estado
  const trips = ref([])
  const loading = ref(false)
  const error = ref(null)

  // Cache para evitar múltiples llamadas - REACTIVO
  const tripsCache = ref({}) // Objeto reactivo en lugar de Map

  // Getters computados
  const tripsCount = computed(() => trips.value.length)
  
  const tripsByDate = computed(() => {
    const grouped = {}
    trips.value.forEach(trip => {
      const date = trip.trip_date
      if (!grouped[date]) {
        grouped[date] = []
      }
      grouped[date].push(trip)
    })
    return grouped
  })

  const tripsByRoute = computed(() => {
    const grouped = {}
    trips.value.forEach(trip => {
      const routeId = trip.id_route
      if (!grouped[routeId]) {
        grouped[routeId] = []
      }
      grouped[routeId].push(trip)
    })
    return grouped
  })

  // Acciones

  /**
   * Obtener trips por ruta y fecha
   */
  const fetchTripsByRouteAndDate = async (routeId, date) => {
    const cacheKey = `${routeId}-${date}`
    
    // Verificar caché primero
    if (tripsCache.value[cacheKey]) {
      console.log(`📦 Usando caché para ruta ${routeId} - ${date}`)
      return tripsCache.value[cacheKey]
    }

    try {
      const result = await tripsApi.getTripsByRouteAndDate(routeId, date)
      
      // Guardar en caché
      tripsCache.value = {
        ...tripsCache.value,
        [cacheKey]: result
      }
      
      // Actualizar estado global (opcional)
      updateTripsInState(result)
      
      console.log(`✅ ${result.length} trips cargados para ruta ${routeId} - ${date}`)
      return result
    } catch (err) {
      // Si es 404, significa que no hay trips para esa ruta/fecha
      if (err.response?.status === 404) {
        tripsCache.value = {
          ...tripsCache.value,
          [cacheKey]: []
        }
        console.log(`ℹ️ No hay trips para ruta ${routeId} - ${date}`)
        return []
      }
      
      // Para otros errores, registrar pero no guardar en caché
      console.error(`❌ Error cargando trips ruta ${routeId} - ${date}:`, err.message)
      throw err
    }
  }

  /**
   * Cargar trips para múltiples rutas y fechas
   */
  const fetchTripsForWeek = async (routes, dates) => {
    loading.value = true
    error.value = null
    let totalTrips = 0

    try {
      console.log(`🚀 Cargando semana (Optimizada): ${dates.length} días...`)
      
      const newCacheEntries = {}
      const allFetchedTrips = []

      // Solo pedimos los días que no tenemos en el "caché de día completo"
      const daysToFetch = dates.filter(date => !tripsCache.value[`all-${date}`])
      
      if (daysToFetch.length > 0) {
        const dayPromises = daysToFetch.map(async (date) => {
          try {
            const result = await tripsApi.listTrips({ trip_date: date, limit: 1000 })
            const dayTrips = result.data || []
            
            // Guardar en caché de día completo
            newCacheEntries[`all-${date}`] = dayTrips
            
            // Agrupar por ruta para llenar el caché por ruta también
            const byRoute = {}
            dayTrips.forEach(t => {
              if (!byRoute[t.id_route]) byRoute[t.id_route] = []
              byRoute[t.id_route].push(t)
            })
            
            // Llenar entradas de caché para cada ruta (incluso las que no tienen viajes)
            routes.forEach(r => {
              newCacheEntries[`${r.id}-${date}`] = byRoute[r.id] || []
            })
            
            return dayTrips
          } catch (err) {
            console.warn(`⚠️ Error cargando día ${date}:`, err.message)
            return []
          }
        })
        
        const dayResults = await Promise.all(dayPromises)
        dayResults.forEach(trips => {
          allFetchedTrips.push(...trips)
          totalTrips += trips.length
        })
      } else {
        console.log('📦 Todos los días de la semana ya están en caché')
      }

      // 1. Actualizar el caché de UNA SOLA VEZ
      if (Object.keys(newCacheEntries).length > 0) {
        tripsCache.value = {
          ...tripsCache.value,
          ...newCacheEntries
        }
      }
      
      // 2. Actualizar el estado global
      if (allFetchedTrips.length > 0) {
        updateTripsInState(allFetchedTrips)
      }

      return totalTrips
    } catch (err) {
      error.value = err.message
      console.error('❌ Error en carga semanal:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Obtener todos los trips de un día (todas las rutas)
   */
  const fetchTripsByDate = async (date) => {
    const cacheKey = `all-${date}`

    if (tripsCache.value[cacheKey]) {
      console.log(`📦 Usando caché all-trips para ${date}`)
      return tripsCache.value[cacheKey]
    }

    try {
      const result = await tripsApi.listTrips({ trip_date: date, limit: 1000 })
      const tripsResult = result.data || []
      tripsCache.value = {
        ...tripsCache.value,
        [cacheKey]: tripsResult
      }
      console.log(`✅ ${tripsResult.length} trips (todas las rutas) cargados para ${date}`)
      return tripsResult
    } catch (err) {
      if (err.response?.status === 404) {
        tripsCache.value = {
          ...tripsCache.value,
          [cacheKey]: []
        }
        return []
      }
      console.error(`❌ Error cargando all-trips para ${date}:`, err.message)
      throw err
    }
  }

  /**
   * Crear un trip individual
   */
  const createTrip = async (tripData) => {
    try {
      loading.value = true
      error.value = null
      
      const result = await tripsApi.createTrip(tripData)
      
      if (result.success) {
        // Invalidar caché para esa ruta/fecha
        const cacheKey = `${tripData.id_route}-${tripData.trip_date}`
        const newCache = { ...tripsCache.value }
        delete newCache[cacheKey]
        tripsCache.value = newCache
        
        console.log('✅ Trip creado:', result.data)
        return result
      } else {
        throw new Error(result.msg || 'Error creando trip')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error creando trip:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear múltiples trips (batch)
   */
  const createTripsBatch = async (batchData) => {
    try {
      loading.value = true
      error.value = null
      
      console.log('📤 Creando batch de trips:', {
        route: batchData.id_route,
        date: batchData.trip_date,
        count: batchData.trips?.length
      })
      
      const result = await tripsApi.createTripsBatch(batchData)
      
      if (result.success) {
        // Invalidar caché para esa ruta/fecha
        const cacheKey = `${batchData.id_route}-${batchData.trip_date}`
        const newCache = { ...tripsCache.value }
        delete newCache[cacheKey]
        tripsCache.value = newCache
        
        console.log('✅ Batch de trips creado:', result.trips_created, 'trips')
        return result
      } else {
        throw new Error(result.msg || 'Error creando trips en batch')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error creando batch de trips:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Asignar/desasignar bus a un trip
   */
  const assignBus = async (tripId, plateNumber, userUpdate) => {
    try {
      loading.value = true
      error.value = null
      
      const result = await tripsApi.setTripBus(tripId, plateNumber, userUpdate)
      
      if (result.success) {
        // Invalidar todo el caché para forzar recarga
        tripsCache.value = {}
        
        console.log('✅ Bus asignado al trip')
        return result
      } else {
        throw new Error(result.msg || 'Error asignando bus')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error asignando bus:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Eliminar trips por ruta/fecha
   */
  const deleteTripsByDate = async (routeId, date) => {
    try {
      loading.value = true
      error.value = null
      
      const result = await tripsApi.deleteTripsByDate(routeId, date)
      
      if (result.success) {
        // Invalidar caché
        const cacheKey = `${routeId}-${date}`
        const newCache = { ...tripsCache.value }
        delete newCache[cacheKey]
        tripsCache.value = newCache
        
        console.log('✅ Trips eliminados')
        return result
      } else {
        throw new Error(result.msg || 'Error eliminando trips')
      }
    } catch (err) {
      error.value = err.message
      console.error('❌ Error eliminando trips:', err)
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Actualizar estado global de trips (helper)
   */
  const updateTripsInState = (newTrips) => {
    if (!newTrips || newTrips.length === 0) return

    // Optimizacion: Evitar O(N^2) al insertar muchos trips
    // 1. Crear un Map con los trips existentes para acceso O(1)
    const tripsMap = new Map()
    trips.value.forEach(t => tripsMap.set(t.id_trip, t))
    
    // 2. Agregar o actualizar con los nuevos trips
    newTrips.forEach(newTrip => {
      tripsMap.set(newTrip.id_trip, newTrip)
    })
    
    // 3. Reasignar el array completo (1 sola actualización reactiva)
    trips.value = Array.from(tripsMap.values())
  }

  /**
   * Insertar o actualizar un solo viaje (Sincronización WebSocket)
   */
  const upsertTrip = (tripData) => {
    if (!tripData || !tripData.id_trip) return
    
    updateTripsInState([tripData])
    
    // Actualizar también el caché
    const cacheKey = `${tripData.id_route}-${tripData.trip_date}`
    if (tripsCache.value[cacheKey]) {
      const idx = tripsCache.value[cacheKey].findIndex(t => t.id_trip === tripData.id_trip)
      if (idx !== -1) {
        tripsCache.value[cacheKey][idx] = tripData
      } else {
        tripsCache.value[cacheKey].push(tripData)
      }
    }
    
    const allDayKey = `all-${tripData.trip_date}`
    if (tripsCache.value[allDayKey]) {
      const idx = tripsCache.value[allDayKey].findIndex(t => t.id_trip === tripData.id_trip)
      if (idx !== -1) {
        tripsCache.value[allDayKey][idx] = tripData
      } else {
        tripsCache.value[allDayKey].push(tripData)
      }
    }
  }

  /**
   * Eliminar un solo viaje de memoria (Sincronización WebSocket)
   */
  const removeTrip = (idTrip) => {
    if (!idTrip) return
    
    const trip = trips.value.find(t => t.id_trip === idTrip)
    trips.value = trips.value.filter(t => t.id_trip !== idTrip)
    
    if (trip) {
      const cacheKey = `${trip.id_route}-${trip.trip_date}`
      if (tripsCache.value[cacheKey]) {
        tripsCache.value[cacheKey] = tripsCache.value[cacheKey].filter(t => t.id_trip !== idTrip)
      }
      const allDayKey = `all-${trip.trip_date}`
      if (tripsCache.value[allDayKey]) {
        tripsCache.value[allDayKey] = tripsCache.value[allDayKey].filter(t => t.id_trip !== idTrip)
      }
    }
  }

  /**
   * Limpiar caché (útil para refrescar datos)
   */
  const clearCache = () => {
    tripsCache.value = {}
    console.log('🗑️ Caché de trips limpiado')
  }

  /**
   * Invalidar caché para una ruta y fecha específica
   */
  const invalidateCache = (routeId, date) => {
    let invalidated = false
    const newCache = { ...tripsCache.value }

    if (routeId) {
      const cacheKey = `${routeId}-${date}`
      if (newCache[cacheKey]) {
        delete newCache[cacheKey]
        invalidated = true
      }
    }

    // También invalidar caché global del día para que otras rutas vean datos frescos
    const allDayKey = `all-${date}`
    if (newCache[allDayKey]) {
      delete newCache[allDayKey]
      invalidated = true
    }

    if (invalidated) {
      tripsCache.value = newCache
      console.log(`🗑️ Caché invalidado${routeId ? ` para ruta ${routeId}` : ''} - ${date} (+ all-day caché)`)
    }
  }

  /**
   * Obtener estadísticas agregadas de trips
   */
  const getStatsForWeek = (routes, dates) => {
    const stats = {
      total: 0,
      assigned: 0,
      pending: 0,
      active: 0,
      byRoute: {}
    }

    // Nota: quitamos los logs excesivos aquí para mejorar rendimiento
    routes.forEach(route => {
      const routeId = route.id
      
      stats.byRoute[routeId] = {
        routeName: route.name,
        total: 0,
        assigned: 0,
        active: 0,
        byDate: {}
      }

      dates.forEach(date => {
        const cacheKey = `${routeId}-${date}`
        const tripsList = tripsCache.value[cacheKey] || []
        
        const assigned = tripsList.filter(t => t.plate_number).length
        const todayStr = new Date().toLocaleDateString('en-CA')
        const active = (date === todayStr) ? tripsList.filter(t => t.status_trip === 3).length : 0

        stats.total += tripsList.length
        stats.assigned += assigned
        stats.active += active
        stats.byRoute[routeId].total += tripsList.length
        stats.byRoute[routeId].assigned += assigned
        stats.byRoute[routeId].active += active
        stats.byRoute[routeId].byDate[date] = {
          total: tripsList.length,
          assigned: assigned,
          active: active
        }
      })
    })

    stats.pending = stats.total - stats.assigned
    return stats
  }

  return {
    // Estado
    trips,
    loading,
    error,
    
    // Getters
    tripsCount,
    tripsByDate,
    tripsByRoute,
    
    // Acciones
    fetchTripsByRouteAndDate,
    fetchTripsByDate,
    fetchTripsForWeek,
    createTrip,
    createTripsBatch,
    assignBus,
    deleteTripsByDate,
    clearCache,
    invalidateCache,
    getStatsForWeek,
    upsertTrip,
    removeTrip
  }
})
