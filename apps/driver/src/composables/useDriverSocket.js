import { ref } from 'vue'
import { io } from 'socket.io-client'
import apiClient from '@shared/api/client'

export function useDriverSocket() {
  const socket = ref(null)
  const isConnected = ref(false)

  // Deriva la URL de WebSocket de la configuración del cliente API (sin el sufijo /api)
  const getWsUrl = () => {
    const baseURL = apiClient.defaults.baseURL || 'http://localhost:3001/api'
    return baseURL.replace(/\/api$/, '')
  }

  const connectWebSocket = () => {
    const wsUrl = getWsUrl()
    const token = localStorage.getItem('bucarabus_token')
    
    socket.value = io(wsUrl, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 1000,
      auth: token ? { token } : {}
    })
    
    socket.value.on('connect', () => {
      console.log('✅ WebSocket conectado')
      isConnected.value = true
    })
    
    socket.value.on('disconnect', () => {
      console.log('❌ WebSocket desconectado')
      isConnected.value = false
    })
    
    socket.value.on('welcome', (data) => {
      console.log('👋 Bienvenida WebSocket:', data.message)
    })
  }

  const disconnectWebSocket = () => {
    if (socket.value) {
      socket.value.disconnect()
      socket.value = null
    }
  }

  const sendLocation = (driverInfo, location, shiftActive) => {
    if (!socket.value || !isConnected.value || !shiftActive) return
    
    const locationData = {
      plateNumber: driverInfo.busPlate,
      busId: driverInfo.busId,
      ambCode: driverInfo.ambCode || null,
      driverId: driverInfo.id,
      driverName: driverInfo.name,
      routeId: driverInfo.routeId,
      lat: location.lat,
      lng: location.lng,
      speed: location.speed || 0,
      accuracy: location.accuracy,
      heading: location.heading,
      timestamp: new Date().toISOString()
    }
    
    socket.value.emit('bus-location', locationData)
    console.log(`📍 Enviando GPS: ${location.lat.toFixed(5)}, ${location.lng.toFixed(5)}`)
  }

  const emitShiftStart = (driverInfo, currentTrip) => {
    if (!socket.value || !currentTrip) return
    socket.value.emit('bus-start-shift', {
      plateNumber: driverInfo.busPlate,
      busId: driverInfo.busId,
      driverId: driverInfo.id,
      driverName: driverInfo.name,
      routeId: driverInfo.routeId,
      tripId: currentTrip.id_trip
    })
  }

  const emitShiftEnd = (driverInfo, currentTrip, shiftDuration, tripsCompleted) => {
    if (!socket.value) return
    socket.value.emit('bus-end-shift', {
      plateNumber: driverInfo.busPlate,
      busId: driverInfo.busId,
      driverId: driverInfo.id,
      tripId: currentTrip?.id_trip,
      duration: shiftDuration,
      tripsCompleted: tripsCompleted
    })
  }

  const emitIncident = (driverInfo, location, currentTrip, incidentId, tag, name, description) => {
    if (!socket.value) return
    socket.value.emit('report-incident', {
      incidentId:  incidentId,
      tag:         tag,
      name:        name,
      descrip:     description || null,
      lat:         location?.lat,
      lng:         location?.lng,
      plateNumber: driverInfo.busPlate,
      tripId:      currentTrip?.id_trip,
      routeId:     driverInfo.routeId,
      timestamp:   new Date().toISOString()
    })
  }

  return {
    socket,
    isConnected,
    connectWebSocket,
    disconnectWebSocket,
    sendLocation,
    emitShiftStart,
    emitShiftEnd,
    emitIncident
  }
}
