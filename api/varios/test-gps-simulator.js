/**
 * 🧪 Simulador de GPS para pruebas
 * 
 * Este script simula buses enviando ubicaciones GPS al servidor WebSocket.
 * Úsalo para probar el monitor en tiempo real.
 * 
 * Ejecutar: node test-gps-simulator.js
 */

import { io } from 'socket.io-client'

const SERVER_URL = 'http://localhost:3001'

// Datos de prueba - buses simulados
const simulatedBuses = [
  {
    plateNumber: 'ABC123',
    routeId: 1,
    driverName: 'Juan Pérez',
    // Ruta simulada: Centro de Bucaramanga
    route: [
      { lat: 7.1190, lng: -73.1227 },
      { lat: 7.1195, lng: -73.1220 },
      { lat: 7.1200, lng: -73.1210 },
      { lat: 7.1210, lng: -73.1200 },
      { lat: 7.1220, lng: -73.1190 },
      { lat: 7.1230, lng: -73.1180 },
      { lat: 7.1240, lng: -73.1170 },
    ]
  },
  {
    plateNumber: 'XYZ789',
    routeId: 2,
    driverName: 'María García',
    route: [
      { lat: 7.1150, lng: -73.1250 },
      { lat: 7.1155, lng: -73.1240 },
      { lat: 7.1160, lng: -73.1230 },
      { lat: 7.1165, lng: -73.1220 },
      { lat: 7.1170, lng: -73.1210 },
    ]
  },
  {
    plateNumber: 'DEF456',
    routeId: 1,
    driverName: 'Carlos Rodríguez',
    route: [
      { lat: 7.1100, lng: -73.1300 },
      { lat: 7.1110, lng: -73.1290 },
      { lat: 7.1120, lng: -73.1280 },
      { lat: 7.1130, lng: -73.1270 },
    ]
  }
]

// Conectar al servidor
console.log(`🔌 Conectando a ${SERVER_URL}...`)

const socket = io(SERVER_URL, {
  transports: ['websocket']
})

socket.on('connect', () => {
  console.log('✅ Conectado al servidor WebSocket')
  console.log('🚌 Iniciando simulación de buses...\n')
  
  // Iniciar turno para cada bus
  simulatedBuses.forEach(bus => {
    console.log(`🚌 ${bus.plateNumber} - Iniciando turno (Conductor: ${bus.driverName})`)
    socket.emit('bus-start-shift', {
      plateNumber: bus.plateNumber,
      routeId: bus.routeId,
      driverName: bus.driverName
    })
  })
  
  // Iniciar simulación de movimiento
  startSimulation()
})

socket.on('disconnect', () => {
  console.log('❌ Desconectado del servidor')
})

socket.on('connect_error', (error) => {
  console.error('❌ Error de conexión:', error.message)
  process.exit(1)
})

// Índices de posición para cada bus
const busPositions = simulatedBuses.map(() => 0)

function startSimulation() {
  // Enviar ubicaciones cada 2 segundos
  setInterval(() => {
    simulatedBuses.forEach((bus, index) => {
      const route = bus.route
      const position = busPositions[index]
      
      // Obtener coordenada actual
      const coord = route[position]
      
      // Agregar algo de variación aleatoria para simular movimiento real
      const lat = coord.lat + (Math.random() - 0.5) * 0.0001
      const lng = coord.lng + (Math.random() - 0.5) * 0.0001
      
      // Calcular velocidad simulada
      const speed = 20 + Math.random() * 20 // 20-40 km/h
      
      // Enviar ubicación
      socket.emit('bus-location', {
        plateNumber: bus.plateNumber,
        lat: lat,
        lng: lng,
        speed: Math.round(speed),
        heading: Math.random() * 360,
        routeId: bus.routeId,
        driverName: bus.driverName
      })
      
      console.log(`📍 ${bus.plateNumber}: ${lat.toFixed(6)}, ${lng.toFixed(6)} | ${Math.round(speed)} km/h`)
      
      // Avanzar al siguiente punto (loop)
      busPositions[index] = (position + 1) % route.length
    })
    console.log('---')
  }, 2000) // Cada 2 segundos
}

// Manejar cierre
process.on('SIGINT', () => {
  console.log('\n🛑 Deteniendo simulación...')
  
  // Terminar turnos
  simulatedBuses.forEach(bus => {
    socket.emit('bus-end-shift', { plateNumber: bus.plateNumber })
  })
  
  setTimeout(() => {
    socket.disconnect()
    process.exit(0)
  }, 1000)
})

console.log('\n💡 Presiona Ctrl+C para detener la simulación\n')
