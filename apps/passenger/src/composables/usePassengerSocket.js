import { ref } from 'vue'
import { io } from 'socket.io-client'

/**
 * Composable que implementa un cliente WebSocket ligero optimizado para la aplicación de Pasajeros.
 *
 * Responsabilidades:
 * 1. Suscripción a Telemetría: Recibe actualizaciones de ubicación de buses específicos
 *    (`bus-location-update`) en tiempo real.
 * 2. Eventos de Operación: Notifica cuando un turno ha finalizado (`shift-ended`),
 *    permitiendo limpiar marcadores obsoletos del mapa del pasajero.
 * 3. Gestión de Conexión: Maneja el ciclo de vida del socket, incluyendo políticas de
 *    reconexión automática para asegurar la continuidad del servicio en redes móviles inestables.
 */
export function usePassengerSocket(apiUrl, { onBusUpdate, onShiftEnded, onIncidentReported } = {}) {
  const isConnected = ref(false)
  let socket = null

  const connect = () => {
    const token = localStorage.getItem('bucarabus_token')
    socket = io(apiUrl, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionAttempts: 10,
      reconnectionDelay: 1000,
      auth: token ? { token } : {}
    })

    socket.on('connect',    () => { console.log('✅ WebSocket conectado');    isConnected.value = true  })
    socket.on('disconnect', () => { console.log('❌ WebSocket desconectado'); isConnected.value = false })
    socket.on('bus-location-update', (data) => { if (onBusUpdate)  onBusUpdate(data)  })
    socket.on('shift-ended',         (data) => { if (onShiftEnded) onShiftEnded(data) })
    socket.on('incident-reported',   (data) => { if (onIncidentReported) onIncidentReported(data) })
    socket.on('incident-resolved',   (data) => { if (onIncidentReported) onIncidentReported({ ...data, resolved: true }) })
  }

  const disconnect = () => {
    if (socket) { socket.disconnect(); socket = null }
  }

  return { isConnected, connect, disconnect }
}
