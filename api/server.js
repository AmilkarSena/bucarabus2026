import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import rateLimit from 'express-rate-limit'
import dotenv from 'dotenv'
import jwt from 'jsonwebtoken'
import { createServer } from 'http'  // 🆕 Para WebSocket
import { Server } from 'socket.io'   // 🆕 Socket.io
import authRouter from './routes/auth.routes.js'          // 🆕 Autenticación
import passwordResetRouter from './routes/password-reset.routes.js' // 🆕 Recuperación de contraseña
import routesRouter from './routes/routes.routes.js'
import driversRouter from './routes/drivers.routes.js'
import busesRouter from './routes/buses.routes.js'
import assignmentsRouter from './routes/assignments.routes.js'
import shiftsRouter from './routes/shifts.routes.js'  // Turnos activos
import tripsRouter from './routes/trips.routes.js'    // 🆕 Viajes/programación
import gpsRouter from './routes/gps.routes.js'        // 🆕 GPS histórico
import geocodingRouter from './routes/geocoding.routes.js' // 🆕 Búsqueda de lugares
import usersRouter from './routes/users.routes.js'        // 🆕 Usuarios y roles
import rolesRouter from './routes/roles.routes.js'        // 🆕 Permisos de roles
import userPermissionsRouter from './routes/user-permissions.routes.js' // 🆕 Overrides por usuario
import catalogsRouter from './routes/catalogs.routes.js'   // 🆕 Catálogos (EPS, ARL)
import incidentsRouter from './routes/incidents.routes.js' // 🆕 Reporte de incidentes
import incidentsService from './services/incidents.service.js' // Servicio de incidentes para sockets

// Cargar variables de entorno
dotenv.config()

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET is required')
}

const app = express()                 // Crear instancia de Express
const httpServer = createServer(app)  // 🆕 Crear servidor HTTP
const PORT = process.env.PORT || 3001

const allowAnonPassengers = process.env.ALLOW_ANON_PASSENGERS === 'true'
const httpAllowlist = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(origin => origin.trim().replace(/\/$/, ''))
  .filter(Boolean)
const socketAllowlist = (process.env.SOCKET_IO_ORIGINS || process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(origin => origin.trim().replace(/\/$/, ''))
  .filter(Boolean)
const allowLocalhost = process.env.NODE_ENV !== 'production'
const socketSecret = process.env.JWT_SECRET

function isOriginAllowed(origin, allowlist) {
  if (!origin) return true

  const normalizedOrigin = origin.replace(/\/$/, '')
  if (normalizedOrigin === 'null') return allowLocalhost
  if (allowlist.includes(normalizedOrigin)) return true
  if (!allowLocalhost) return false

  return (
    /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(normalizedOrigin) ||
    /^https?:\/\/192\.168\.\d+\.\d+(:\d+)?$/.test(normalizedOrigin) ||
    /^https?:\/\/10\.\d+\.\d+\.\d+(:\d+)?$/.test(normalizedOrigin) ||
    /^https?:\/\/172\.(1[6-9]|2\d|3[01])\.\d+\.\d+(:\d+)?$/.test(normalizedOrigin)
  )
}

function isAdmin(user) {
  return user?.id_role === 1 || (Array.isArray(user?.roles) && user.roles.some(r => r.id_role === 1))
}

function isDriver(user) {
  return user?.id_role === 3 || (Array.isArray(user?.roles) && user.roles.some(r => r.id_role === 3))
}

// ============================================
// 🔌 CONFIGURAR WEBSOCKET (Socket.io)
// ============================================
const io = new Server(httpServer, {
  cors: {
    origin: (origin, callback) => {
      if (isOriginAllowed(origin, socketAllowlist)) return callback(null, true)
      return callback(new Error('Not allowed by CORS'), false)
    },
    methods: ['GET', 'POST'],
    credentials: true
  },
  pingTimeout: 60000,
  pingInterval: 25000
})

io.use((socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.headers?.authorization?.split(' ')[1]

  if (!token) {
    if (allowAnonPassengers) {
      socket.user = { id_role: 0, roles: [], permissions: [] }
      socket.isAnonymous = true
      return next()
    }
    return next(new Error('Unauthorized'))
  }

  try {
    const decoded = jwt.verify(token, socketSecret)
    socket.user = decoded
    socket.isAnonymous = false
    return next()
  } catch (error) {
    return next(new Error('Unauthorized'))
  }
})

// Almacenar ubicaciones de buses en memoria
const busLocations = new Map()
const connectedClients = new Set()

// Eventos de Socket.io
io.on('connection', (socket) => {
  console.log(`✅ WebSocket: Cliente conectado - ${socket.id}`)
  connectedClients.add(socket.id)
  
  // Enviar bienvenida
  socket.emit('welcome', {
    message: 'Conectado a BucaraBus en tiempo real',
    timestamp: new Date().toISOString(),
    activeBuses: busLocations.size
  })

  // Enviar todas las ubicaciones actuales
  socket.emit('all-locations', Array.from(busLocations.values()))

  // 📍 Recibir ubicación de un bus
  socket.on('bus-location', async (data) => {
    if (!isAdmin(socket.user) && !isDriver(socket.user) && !data.simulated) {
      socket.emit('auth-error', { message: 'No autorizado para enviar ubicaciones' })
      return
    }
    console.log(`📍 GPS Bus ${data.plateNumber}: ${data.lat}, ${data.lng}`)
    
    const locationData = {
      ...data,
      lastUpdate: new Date().toISOString(),
      socketId: socket.id
    }
    busLocations.set(data.plateNumber, locationData)
    
    // Nota: Las ubicaciones GPS en tiempo real se manejan solo en memoria vía WebSocket
    // No se persisten en BD para mantener el rendimiento alto
    
    // Emitir a TODOS los clientes (incluyendo app pasajeros)
    // broadcastData usa latitude/longitude para la app de pasajeros
    const broadcastData = {
      busId: data.plateNumber,
      plate: data.plateNumber,
      latitude: data.lat,
      longitude: data.lng,
      speed: data.speed || 0,
      heading: data.heading || 0,
      routeId: data.routeId,
      routeName: data.routeName,
      routeColor: data.routeColor,
      driverId: data.driverId,
      timestamp: new Date().toISOString()
    };
    
    // Evento para la app de pasajeros (usa latitude/longitude)
    io.emit('bus-location-update', broadcastData);
    
    // Evento para el monitor admin (usa lat/lng que es lo que normalizeBusData espera)
    // IMPORTANTE: Un solo emit, no duplicar para evitar vibración del marcador
    io.emit('bus-moved', locationData)
  })

  // 📡 Solicitar todas las ubicaciones
  socket.on('get-all-locations', () => {
    if (!socket.user && !socket.isAnonymous) {
      socket.emit('auth-error', { message: 'No autorizado' })
      return
    }
    socket.emit('all-locations', Array.from(busLocations.values()))
  })

  // 🚌 Bus inicia turno
  socket.on('bus-start-shift', (data) => {
    if (!isAdmin(socket.user) && !isDriver(socket.user)) {
      socket.emit('auth-error', { message: 'No autorizado para iniciar turno' })
      return
    }
    console.log(`🚌 Bus ${data.plateNumber} inició turno`)
    io.emit('shift-started', { ...data, startTime: new Date().toISOString() })
  })

  // 🏁 Bus termina turno
  socket.on('bus-end-shift', (data) => {
    if (!isAdmin(socket.user) && !isDriver(socket.user)) {
      socket.emit('auth-error', { message: 'No autorizado para finalizar turno' })
      return
    }
    console.log(`🏁 Bus ${data.plateNumber} terminó turno`)
    busLocations.delete(data.plateNumber)
    io.emit('shift-ended', { ...data, endTime: new Date().toISOString() })
  })

  // 🚨 Reportar Incidente (conductor)
  socket.on('report-incident', async (data) => {
    if (!isAdmin(socket.user) && !isDriver(socket.user)) {
      socket.emit('auth-error', { message: 'No autorizado para reportar incidentes' })
      return
    }
    console.log(`🚨 Incidente reportado por ${data.plateNumber}: ${data.type}`)
    // Reemitir inmediatamente a todos los pasajeros conectados
    io.emit('incident-reported', {
      ...data,
      timestamp: new Date().toISOString()
    })
    // Persistir en BD (no bloqueante)
    incidentsService.createIncident(data).catch(console.error)
  })

  // ❌ Desconexión
  socket.on('disconnect', (reason) => {
    console.log(`❌ WebSocket: Cliente desconectado - ${socket.id} (${reason})`)
    connectedClients.delete(socket.id)
    
    // Buscar si era un bus
    for (const [plateNumber, data] of busLocations.entries()) {
      if (data.socketId === socket.id) {
        busLocations.delete(plateNumber)
        io.emit('bus-disconnected', { plateNumber })
        break
      }
    }
  })
})

// Hacer io disponible para otros módulos
app.set('io', io)
app.set('busLocations', busLocations)

// Middleware - Seguridad basica
app.use(helmet({
  contentSecurityPolicy: false
}))

// Middleware - CORS abierto para desarrollo
app.use(cors({
  origin: (origin, callback) => {
    if (isOriginAllowed(origin, httpAllowlist)) return callback(null, true)
    return callback(new Error('Not allowed by CORS'))
  },
  credentials: true
}))

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: process.env.NODE_ENV === 'production' ? 5 : 100,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Demasiados intentos. Intenta nuevamente mas tarde.'
  }
})

app.use(express.json())
app.use(express.urlencoded({ extended: true }))

// Logger middleware
function redactSensitiveFields(payload) {
  if (!payload || typeof payload !== 'object') return payload
  const redacted = Array.isArray(payload) ? [...payload] : { ...payload }
  const sensitiveKeys = new Set(['password', 'newPassword', 'token', 'authorization', 'refreshToken'])

  for (const key of Object.keys(redacted)) {
    if (sensitiveKeys.has(key)) {
      redacted[key] = '[REDACTED]'
      continue
    }
    if (redacted[key] && typeof redacted[key] === 'object') {
      redacted[key] = redactSensitiveFields(redacted[key])
    }
  }

  return redacted
}

app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`)
  console.log(`   Headers:`, req.headers['content-type'])
  if (req.method === 'POST' && process.env.NODE_ENV !== 'production') {
    const safeBody = redactSensitiveFields(req.body)
    console.log(`   Body:`, JSON.stringify(safeBody, null, 2))
  }
  next()
})

// Welcome route
app.get('/', (req, res) => {
  res.json({
    success: true,
    message: '🚌 BucaraBus API Server',
    version: '1.0.0',
    timestamp: new Date().toISOString(),
    endpoints: {
      health: '/health',
      routes: '/api/routes',
      drivers: '/api/drivers',
      buses: '/api/buses',
      assignments: '/api/assignments',
      shifts: '/api/shifts',  // 🆕 Turnos activos
      users: '/api/users',    // 🆕 Usuarios y roles
      documentation: 'Ver README.md para más información'
    }
  })
})

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'OK',
    timestamp: new Date().toISOString(),
    service: 'BucaraBus API',
    version: '1.0.0',
    websocket: {
      connectedClients: connectedClients.size,
      activeBuses: busLocations.size
    }
  })
})

// API Routes
app.use('/api/auth', authLimiter)      // Rate limit para auth
app.use('/api/auth', authRouter)       // 🆕 Autenticación
app.use('/api/auth', passwordResetRouter) // 🆕 Recuperación de contraseña
app.use('/api/routes', routesRouter)  // Rutas de buses
app.use('/api/drivers', driversRouter) // Conductores
app.use('/api/buses', busesRouter)     // Buses
app.use('/api/assignments', assignmentsRouter)// Asignaciones conductor-bus-ruta
app.use('/api/shifts', shiftsRouter)  // Turnos activos
app.use('/api/trips', tripsRouter)    // 🆕 Viajes/programación
app.use('/api/gps', gpsRouter)        // 🆕 GPS histórico
app.use('/api/geocoding', geocodingRouter) // 🆕 Búsqueda de lugares
app.use('/api/users', usersRouter)    // 🆕 Usuarios y roles
app.use('/api/users', userPermissionsRouter) // 🆕 Overrides de permisos por usuario
app.use('/api/roles', rolesRouter)    // 🆕 Permisos de roles
app.use('/api/catalogs', catalogsRouter) // 🆕 Catálogos (EPS, ARL)
app.use('/api/incidents', incidentsRouter) // 🆕 Reporte de incidentes

// Proxy de enrutamiento: orden controlado por ROUTING_ENGINES en .env
// Decodifica polyline de Valhalla (precisión 6)
function decodeValhallaPoly(encoded) {
  const coords = []
  let index = 0, lat = 0, lng = 0
  while (index < encoded.length) {
    let b, shift = 0, result = 0
    do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5 } while (b >= 0x20)
    lat += (result & 1) ? ~(result >> 1) : (result >> 1)
    shift = result = 0
    do { b = encoded.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5 } while (b >= 0x20)
    lng += (result & 1) ? ~(result >> 1) : (result >> 1)
    coords.push([lng / 1e6, lat / 1e6])
  }
  return coords
}

// Funciones individuales por motor — devuelven { code:'Ok', routes:[...] } o null
async function tryOrs(waypoints) {
  const orsKey = process.env.ORS_API_KEY
  if (!orsKey) return null
  const coords = waypoints.split(';').map(p => p.split(',').map(Number))
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 12000)
  try {
    const res = await fetch('https://api.openrouteservice.org/v2/directions/driving-car/geojson', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': orsKey },
      body: JSON.stringify({ coordinates: coords }),
      signal: controller.signal
    })
    clearTimeout(timer)
    if (!res.ok) { console.warn('[ORS] HTTP:', res.status); return null }
    const data = await res.json()
    const geometry = data.features?.[0]?.geometry
    const distance = data.features?.[0]?.properties?.summary?.distance
    if (geometry?.coordinates?.length > 1) {
      console.log(`[ORS] OK: ${geometry.coordinates.length} puntos, ${Math.round(distance)}m`)
      return { code: 'Ok', routes: [{ geometry, distance }] }
    }
  } catch (e) {
    clearTimeout(timer)
    console.warn('[ORS] Error:', e.message)
  }
  return null
}

async function tryOsrm(waypoints) {
  const servers = [
    `https://router.project-osrm.org/route/v1/driving/${waypoints}?overview=full&geometries=geojson&steps=false`,
    `https://routing.openstreetmap.de/routed-car/route/v1/driving/${waypoints}?overview=full&geometries=geojson&steps=false`
  ]
  for (const url of servers) {
    const controller = new AbortController()
    const timer = setTimeout(() => controller.abort(), 8000)
    try {
      const res = await fetch(url, { signal: controller.signal })
      clearTimeout(timer)
      if (!res.ok) continue
      const data = await res.json()
      if (data.code === 'Ok') { console.log(`[OSRM] OK`); return data }
    } catch (e) {
      clearTimeout(timer)
      console.warn('[OSRM] Error:', e.message)
    }
  }
  return null
}

async function tryValhalla(waypoints) {
  const pairs = waypoints.split(';').map(p => { const [lon, lat] = p.split(',').map(Number); return { lon, lat } })
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 15000)
  try {
    const res = await fetch('https://valhalla1.openstreetmap.de/route', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ locations: pairs, costing: 'auto' }),
      signal: controller.signal
    })
    clearTimeout(timer)
    if (!res.ok) { console.warn('[Valhalla] HTTP:', res.status); return null }
    const data = await res.json()
    if (data.trip?.legs?.length) {
      const allCoords = []
      for (const leg of data.trip.legs) {
        const legCoords = decodeValhallaPoly(leg.shape)
        if (allCoords.length > 0) legCoords.shift()
        allCoords.push(...legCoords)
      }
      const distance = (data.trip.summary?.length || 0) * 1000
      console.log(`[Valhalla] OK: ${allCoords.length} puntos, ${Math.round(distance)}m`)
      return { code: 'Ok', routes: [{ geometry: { coordinates: allCoords }, distance }] }
    }
  } catch (e) {
    clearTimeout(timer)
    console.warn('[Valhalla] Error:', e.message)
  }
  return null
}

const engineFns = { ors: tryOrs, osrm: tryOsrm, valhalla: tryValhalla }

// Orden leído de .env al arrancar (ej: "ors,osrm,valhalla")
const routingEngines = (process.env.ROUTING_ENGINES || 'ors,osrm,valhalla')
  .split(',')
  .map(e => e.trim().toLowerCase())
  .filter(e => engineFns[e])

console.log(`🗺️ Motores de enrutamiento: ${routingEngines.join(' → ')}`)

app.get('/api/osrm/route', async (req, res) => {
  const { waypoints } = req.query
  if (!waypoints) return res.status(400).json({ error: 'waypoints requerido' })

  for (const engine of routingEngines) {
    const result = await engineFns[engine](waypoints)
    if (result) return res.json(result)
  }

  res.status(503).json({ error: 'Servicio de rutas no disponible' })
})
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint no encontrado',
    path: req.path
  })
})

// Error handler
app.use((error, req, res, next) => {
  console.error('❌ Error:', error)
  res.status(500).json({
    success: false,
    error: 'Error interno del servidor',
    message: process.env.NODE_ENV === 'development' ? error.message : undefined
  })
})

// Iniciar servidor HTTP (no app.listen, porque usamos httpServer para WebSocket)
httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`
╔════════════════════════════════════════╗
║   🚌 BucaraBus API Server              ║
║   🌐 http://localhost:${PORT}            ║
║   🌐 Network: http://0.0.0.0:${PORT}     ║
║   🔌 WebSocket: Activo                 ║
║   📊 Environment: ${process.env.NODE_ENV || 'development'}       ║
║   🗄️  Database: PostgreSQL + PostGIS   ║
╚════════════════════════════════════════╝
  `)
})

export default app
