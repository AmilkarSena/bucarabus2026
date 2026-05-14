import { ref, onMounted, onUnmounted } from 'vue'
import { getActiveShifts } from '../api/shifts'
import { useWebSocket } from './useWebSocket'

/**
 * Composable que actúa como el "Hub Central" de datos para el módulo de Monitoreo.
 * 
 * Su responsabilidad es orquestar dos flujos de datos complementarios:
 * 1. Flujo de Negocio (HTTP Polling): Cada 5 segundos consulta los turnos activos 
 *    en el servidor para identificar qué rutas y buses deberían estar operando.
 * 2. Flujo de Telemetría (WebSocket): Se conecta al socket de tiempo real para recibir 
 *    coordenadas GPS directas de los buses activos.
 * 
 * El módulo procesa estos datos para generar una estructura de "Rutas Activas" que 
 * agrupa los buses por su trayecto correspondiente, facilitando la visualización en 
 * listas y en el mapa.
 * 
 * @returns {Object} Datos de rutas activas, estado de conexión y ubicaciones GPS.
 */

export function useMonitorData() {
  const activeRoutesData = ref([])
  let refreshInterval = null

  // WebSocket Integration
  const { 
    connect, 
    disconnect, 
    isConnected, 
    busLocations: wsLocations,
    connectionError,
    requestAllLocations 
  } = useWebSocket()

  // Cargar rutas activas desde API de turnos
  const loadActiveRoutes = async () => {
    try {
      console.log('📡 Cargando turnos activos desde API...')
      
      const shifts = await getActiveShifts()
      console.log('📦 Turnos recibidos:', shifts.length)
      
      const routesMap = new Map()
      
      shifts.forEach(shift => {
        const routeId = Number(shift.id_route)
        
        if (!routesMap.has(routeId)) {
          let pathCoords = []
          if (shift.path_route && shift.path_route.coordinates) {
            pathCoords = shift.path_route.coordinates.map(coord => [coord[1], coord[0]])
          }
          
          routesMap.set(routeId, {
            id: routeId,
            name: shift.name_route,
            color: shift.color_route || '#667eea',
            path: pathCoords,
            busesActivos: 0,
            tripsActivos: 0,
            buses: []
          })
        }
        
        const route = routesMap.get(routeId)
        route.busesActivos++
        route.tripsActivos++
        route.buses.push({
          id_bus: shift.plate_number,
          placa: shift.amb_code || shift.plate_number,
          conductor: shift.name_driver || 'Sin asignar',
          progreso_ruta: shift.progress_percentage || 0,
          viajes_completados: shift.trips_completed || 0,
          lat: shift.current_lat,
          lng: shift.current_lng,
          gps_active: shift.gps_active || false,
          status_trip: shift.status_trip,
          start_time: shift.started_at,
          end_time: shift.end_time
        })
      })
      
      activeRoutesData.value = Array.from(routesMap.values())
      console.log('✅ Rutas activas procesadas:', activeRoutesData.value.length)
    } catch (error) {
      console.error('❌ Error cargando turnos activos:', error)
      if (activeRoutesData.value.length === 0) {
        activeRoutesData.value = []
      }
    }
  }

  onMounted(() => {
    console.log('🚀 Monitor Data montado')
    
    // Conectar WebSocket
    const wsUrl = import.meta.env.VITE_WS_URL || 'http://localhost:3001'
    connect(wsUrl)
    
    // Iniciar polling HTTP
    loadActiveRoutes()
    refreshInterval = setInterval(loadActiveRoutes, 5000)
  })

  onUnmounted(() => {
    if (refreshInterval) {
      clearInterval(refreshInterval)
    }
    disconnect()
    console.log('⏹️ Monitor Data desmontado')
  })

  return {
    activeRoutesData,
    isConnected,
    wsLocations,
    connectionError,
    loadActiveRoutes
  }
}
