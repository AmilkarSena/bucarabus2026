/**
 * Composable que gestiona la comunicación bidireccional en tiempo real mediante WebSockets (Socket.io).
 * 
 * Implementa un patrón Singleton para asegurar que solo exista una conexión activa en toda 
 * la aplicación, centralizando los datos de telemetría:
 * 1. Gestión de Ciclo de Vida: Maneja conexión, reconexión automática y desconexión limpia del servidor.
 * 2. Normalización de Telemetría: Estandariza los mensajes recibidos desde diversos dispositivos 
 *    (GPS trackers, apps de conductores) en un formato de datos único para el frontend.
 * 3. Estado Global Reactivo: Mantiene un `Map` y un `Array` de ubicaciones que se actualizan 
 *    instantáneamente en todos los componentes que inyecten este composable.
 * 4. Comunicación Bidireccional: Provee métodos tanto para recibir datos del servidor como 
 *    para enviar la ubicación y estado del turno desde la app del conductor.
 */

import { ref, shallowRef, triggerRef, onMounted, onUnmounted, readonly } from 'vue'
import { io } from 'socket.io-client'
import { useBusesStore } from '../stores/buses'
import { useDriversStore } from '../stores/drivers'
import { useTripsStore } from '../stores/trips'
import { useIncidentsStore } from '../stores/incidents'

// Estado global (singleton)
let socket = null
const isConnected = ref(false)
const busLocations = ref(new Map())
const connectionError = ref(null)
const serverStats = ref({ activeBuses: 0, connectedClients: 0 })

// Convertir Map a Array reactivo para Vue
const busLocationsArray = shallowRef([])

export function useWebSocket() {
  /**
   * Conectar al servidor WebSocket
   */
  const connect = (url = import.meta.env.VITE_WS_URL || 'http://localhost:3001') => {
    // Prevenir conexiones duplicadas: verificar si ya existe un socket
    // (conectado O en proceso de conexión)
    if (socket) {
      console.log('🔌 Socket ya existe, no se crea otro')
      return
    }

    console.log(`🔌 Conectando a WebSocket: ${url}`)
    
    socket = io(url, {
      transports: ['polling', 'websocket'],
      reconnection: true,
      reconnectionAttempts: Infinity,
      reconnectionDelay: 1000
    })

    // ============================================
    // EVENTOS DE CONEXIÓN
    // ============================================

    socket.on('connect', () => {
      console.log('✅ WebSocket conectado:', socket.id)
      isConnected.value = true
      connectionError.value = null
    })

    socket.on('disconnect', (reason) => {
      console.log('❌ WebSocket desconectado:', reason)
      isConnected.value = false
    })

    socket.on('connect_error', (error) => {
      console.error('❌ Error de conexión:', error.message)
      connectionError.value = error.message
      isConnected.value = false
    })

    // ============================================
    // EVENTOS DE DATOS
    // ============================================

    // Normalizar datos del bus para uso consistente
    const normalizeBusData = (data) => ({
      ...data,
      busId: data.plateNumber || data.busId, // Usar plateNumber como ID
      ambCode: data.ambCode || null,
      driverId: data.driverId || null,
      driverName: data.driverName || null,
      lat: data.lat,
      lng: data.lng,
      speed: data.speed || 0,
      heading: data.heading || 0,
      routeColor: data.routeColor || '#3b82f6',
      timestamp: data.timestamp || data.lastUpdate || new Date().toISOString()
    })

    // Mensaje de bienvenida
    socket.on('welcome', (data) => {
      console.log('👋 Bienvenida del servidor:', data)
      serverStats.value.activeBuses = data.activeBuses || 0
    })

    // Recibir todas las ubicaciones
    socket.on('all-locations', (locations) => {
      busLocations.value.clear()
      locations.forEach(loc => {
        const normalized = normalizeBusData(loc)
        busLocations.value.set(normalized.busId, normalized)
      })
      updateLocationsArray()
    })

    // Un bus se movió
    socket.on('bus-moved', (data) => {
      const normalized = normalizeBusData(data)
      busLocations.value.set(normalized.busId, normalized)
      triggerRef(busLocations)
      throttledUpdateArray()
    })

    // Un bus se desconectó
    socket.on('bus-disconnected', (data) => {
      const busId = data.plateNumber || data.busId
      busLocations.value.delete(busId)
      triggerRef(busLocations)
      updateLocationsArray()
    })

    // Un bus inició turno
    socket.on('shift-started', (data) => {
      // Logic for shift started
    })

    // Un bus terminó turno
    socket.on('shift-ended', (data) => {
      busLocations.value.delete(data.plateNumber)
      updateLocationsArray()
    })

    // ============================================
    // EVENTOS DE GESTIÓN OPERATIVA (Sincronización en tiempo real)
    // ============================================

    socket.on('bus-updated', (data) => {
      console.log('🔄 Actualización de bus recibida:', data)
      const busesStore = useBusesStore()
      busesStore.fetchBuses()
    })

    socket.on('driver-updated', (data) => {
      console.log('🔄 Actualización de conductor recibida:', data)
      const driversStore = useDriversStore()
      driversStore.fetchDrivers()
    })

    socket.on('trip-updated', (tripData) => {
      console.log('🔄 Actualización de viaje recibida:', tripData.id_trip)
      const tripsStore = useTripsStore()
      tripsStore.upsertTrip(tripData)
    })

    socket.on('trip-deleted', (data) => {
      console.log('🗑️ Eliminación de viaje recibida:', data.id_trip)
      const tripsStore = useTripsStore()
      tripsStore.removeTrip(data.id_trip)
    })

    socket.on('trips-batch-updated', (data) => {
      console.log('🔄 Actualización masiva de viajes recibida:', data)
      const tripsStore = useTripsStore()
      tripsStore.invalidateCache(data.id_route, data.trip_date)
      // Si la fecha actual coincide con la modificada, recargamos los datos base
      tripsStore.fetchTripsByDate(data.trip_date)
    })

    // Incidentes
    socket.on('incident-reported', (incident) => {
      console.log('🚨 Incidente reportado en tiempo real:', incident)
      const incidentsStore = useIncidentsStore()
      incidentsStore.addIncident(incident)
    })

    socket.on('incident-resolved', (data) => {
      console.log('✅ Incidente resuelto en tiempo real:', data.id)
      const incidentsStore = useIncidentsStore()
      incidentsStore.removeIncident(data.id)
    })
  }

  /**
   * Desconectar
   */
  const disconnect = () => {
    if (socket) {
      socket.disconnect()
      socket = null
      isConnected.value = false
      console.log('🔌 Desconectado manualmente')
    }
  }

  /**
   * Actualizar array reactivo de ubicaciones
   */
  const updateLocationsArray = () => {
    busLocationsArray.value = Array.from(busLocations.value.values())
    triggerRef(busLocationsArray)
  }

  // Throttling para actualizaciones frecuentes (ej: movimiento de buses)
  let updateTimeout = null
  const throttledUpdateArray = () => {
    if (updateTimeout) return
    
    updateTimeout = setTimeout(() => {
      updateLocationsArray()
      updateTimeout = null
    }, 100) // Máximo 10 actualizaciones por segundo
  }

  /**
   * Enviar ubicación del bus (para app del conductor)
   */
  const sendLocation = (plateNumber, lat, lng, extraData = {}) => {
    if (!socket?.connected) {
      console.error('❌ No conectado al servidor')
      return false
    }

    socket.emit('bus-location', {
      plateNumber,
      lat,
      lng,
      timestamp: new Date().toISOString(),
      ...extraData
    })
    return true
  }

  /**
   * Iniciar turno (para app del conductor)
   */
  const startShift = (plateNumber, routeId, driverName) => {
    if (!socket?.connected) return false
    
    socket.emit('bus-start-shift', {
      plateNumber,
      routeId,
      driverName
    })
    return true
  }

  /**
   * Terminar turno (para app del conductor)
   */
  const endShift = (plateNumber) => {
    if (!socket?.connected) return false
    
    socket.emit('bus-end-shift', { plateNumber })
    return true
  }

  /**
   * Solicitar todas las ubicaciones
   */
  const requestAllLocations = () => {
    if (socket?.connected) {
      socket.emit('get-all-locations')
    }
  }

  /**
   * Obtener ubicación de un bus específico
   */
  const getBusLocation = (plateNumber) => {
    return busLocations.value.get(plateNumber) || null
  }

  return {
    // Estado (readonly para evitar modificaciones accidentales)
    isConnected: readonly(isConnected),
    connectionError: readonly(connectionError),
    busLocations: busLocations,              // Map original
    busLocationsArray: busLocationsArray,    // Array para iteración en Vue
    serverStats: readonly(serverStats),
    
    // Métodos
    connect,
    disconnect,
    sendLocation,
    startShift,
    endShift,
    requestAllLocations,
    getBusLocation
  }
}
