import { ref } from 'vue'

const CACHE_KEY = 'bucarabus_routes_cache'
const CACHE_TIMESTAMP_KEY = 'bucarabus_routes_timestamp'

export function useRoutesCache(apiUrl) {
  const cachedRoutes = ref([])
  const isOffline = ref(false)
  const lastSync = ref(null)

  const loadFromCache = () => {
    try {
      const data = localStorage.getItem(CACHE_KEY)
      const timestamp = localStorage.getItem(CACHE_TIMESTAMP_KEY)
      if (data) {
        cachedRoutes.value = JSON.parse(data)
        if (timestamp) lastSync.value = new Date(parseInt(timestamp))
        return true
      }
    } catch (e) {
      console.error('Error leyendo caché de rutas:', e)
    }
    return false
  }

  const saveToCache = (routesData) => {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify(routesData))
      const now = Date.now()
      localStorage.setItem(CACHE_TIMESTAMP_KEY, now.toString())
      lastSync.value = new Date(now)
    } catch (e) {
      console.error('Error guardando rutas en caché (posible límite de cuota):', e)
    }
  }

  const loadRoutesWithCache = async () => {
    try {
      // Evitar URLs relativas de protocolo como "//api/routes"
      const baseUrl = apiUrl.endsWith('/') ? apiUrl.slice(0, -1) : apiUrl
      const response = await fetch(`${baseUrl || ''}/api/routes`)
      if (!response.ok) throw new Error('Network response was not ok')
      
      const data = await response.json()
      if (data.success && data.data) {
        // Mapear rutas al formato usado por la app
        const formattedRoutes = data.data.map(r => ({
          id: r.id, 
          name: r.name || `Ruta ${r.id}`, 
          color: r.color || '#667eea',
          path: r.path || r.path_route?.coordinates || [],
          stops: r.stops || r.points || [], 
          fare: r.fare ?? 0, 
          isCircular: r.isCircular ?? true
        }))
        
        cachedRoutes.value = formattedRoutes
        isOffline.value = false
        saveToCache(formattedRoutes)
        return formattedRoutes
      }
    } catch (error) {
      console.warn('Fallo al obtener rutas del servidor, usando caché local.', error)
      isOffline.value = true
      loadFromCache()
    }
    return cachedRoutes.value
  }

  return {
    cachedRoutes,
    isOffline,
    lastSync,
    loadRoutesWithCache
  }
}
