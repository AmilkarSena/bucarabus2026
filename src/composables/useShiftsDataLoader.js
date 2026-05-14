/**
 * Composable especializado en la carga y normalización de datos para el sistema de turnos.
 * 
 * Responsabilidades:
 * 1. Orquestación de Carga Inicial: Carga buses, conductores y rutas de forma concurrente con timeout.
 * 2. Carga de Viajes por Fecha: Consulta los viajes de una ruta y fecha específica.
 * 3. Normalización (ETL): Transforma los datos crudos de la base de datos al formato reactivo 
 *    del frontend usando useShiftTripFactory.
 * 4. Validación Cross-Route: Carga todos los viajes del día (otras rutas) para permitir 
 *    la detección de solapamientos de buses entre diferentes líneas.
 */

export function useShiftsDataLoader({
  trips,
  allDayTrips,
  busesStore,
  driversStore,
  routesStore,
  tripsStore,
  tripFromDatabase,
  batchColors,
  calculateDuration
}) {

  /**
   * Carga los datos maestros necesarios para el modal (Buses, Conductores, Rutas)
   * e intenta cargar los viajes existentes si hay una ruta/fecha preseleccionada.
   */
  const loadData = async (initialRouteId, initialDate) => {
    try {
      // Timeout de 8 segundos para no bloquear indefinidamente
      const timeout = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Timeout cargando datos maestros')), 8000)
      )
      
      const promises = []
      
      if (!busesStore.buses || busesStore.buses.length === 0) {
        promises.push(busesStore.fetchBuses())
      }
      
      if (!driversStore.drivers || driversStore.drivers.length === 0) {
        promises.push(driversStore.fetchDrivers())
      }
      
      if (!routesStore.routesList || routesStore.routesList.length === 0) {
        promises.push(routesStore.loadRoutes())
      }

      if (promises.length > 0) {
        await Promise.race([
          Promise.all(promises),
          timeout
        ])
      }
      
      // Si ya tenemos ruta y fecha, cargar los viajes de una vez
      if (initialRouteId && initialDate) {
        await loadExistingTrips(initialRouteId, initialDate)
      }
    } catch (error) {
      console.error('❌ [DataLoader] Error en carga inicial:', error)
      throw error // Re-lanzar para que el componente decida si mostrar alerta
    }
  }

  /**
   * Carga viajes existentes de la BD para una combinación específica de ruta y fecha.
   */
  const loadExistingTrips = async (initialRouteId, initialDate) => {
    try {
      // 1. Formatear fecha
      const tripDate = typeof initialDate === 'string' 
        ? initialDate.split('T')[0]
        : initialDate.toISOString().split('T')[0]
      
      const numericRouteId = initialRouteId
      
      if (!numericRouteId) {
        console.warn('⚠️ [DataLoader] Intento de carga sin ID de ruta')
        return
      }
      
      console.log(`🔍 [DataLoader] Cargando viajes: Ruta ${numericRouteId}, Fecha ${tripDate}`)
      
      // 2. Cargar viajes de la ruta actual
      const existingTrips = await tripsStore.fetchTripsByRouteAndDate(numericRouteId, tripDate)
      
      if (existingTrips && existingTrips.length > 0) {
        // Normalización usando el factory
        trips.value = existingTrips.map((trip, index) => {
          return tripFromDatabase(trip, index, initialRouteId, batchColors, calculateDuration)
        })
        console.log(`✅ [DataLoader] ${existingTrips.length} viajes cargados y normalizados`)
      } else {
        trips.value = []
        console.log('📭 [DataLoader] No hay viajes para esta combinación')
      }

      // 3. Cargar todos los viajes del día (todas las rutas) para validación de solapamiento
      // NO invalidamos el caché aquí; dejamos que fetchTripsByDate use el caché si existe
      // tripsStore.invalidateCache(null, tripDate)
      
      try {
        const allTrips = await tripsStore.fetchTripsByDate(tripDate)
        const currentRouteIdStr = String(initialRouteId)
        
        allDayTrips.value = allTrips
          .filter(t => String(t.id_route) !== currentRouteIdStr)
          .map(t => ({
            id: t.id_trip,
            startTime: t.start_time.substring(0, 5),
            endTime: t.end_time.substring(0, 5),
            busId: t.plate_number || null,
            status_trip: t.status_trip,
            routeId: t.id_route
          }))
        console.log(`🌐 [DataLoader] ${allDayTrips.value.length} viajes externos cargados para validación`)
      } catch (err) {
        console.warn('⚠️ [DataLoader] No se pudieron cargar viajes de otras rutas:', err.message)
        allDayTrips.value = []
      }
    } catch (error) {
      console.error('❌ [DataLoader] Error cargando viajes existentes:', error)
      throw error
    }
  }

  return {
    loadData,
    loadExistingTrips
  }
}
