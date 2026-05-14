// Test para verificar el formato de datos
import { routesApi } from './api/routes.js'
import * as tripsApi from './api/trips.js'

console.log('🧪 Test de formato de datos...\n')

// Test 1: Cargar rutas
try {
  const routesResponse = await routesApi.getAll()
  console.log('📊 Rutas cargadas:', routesResponse.count)
  
  if (routesResponse.data && routesResponse.data.length > 0) {
    const firstRoute = routesResponse.data[0]
    console.log('Primera ruta:', {
      id: firstRoute.id,
      code: firstRoute.code,
      tipo_id: typeof firstRoute.id,
      name: firstRoute.name
    })
    
    // Test 2: Cargar trips para la primera ruta
    console.log('\n🔍 Intentando cargar trips...')
    const testDate = '2026-02-16'
    const routeId = firstRoute.id
    
    console.log(`Consultando trips para ruta ${routeId} (${typeof routeId}) en fecha ${testDate}`)
    
    try {
      const trips = await tripsApi.getTripsByRouteAndDate(routeId, testDate)
      console.log(`✅ ${trips.length} trips encontrados`)
      if (trips.length > 0) {
        console.log('Primer trip:', trips[0])
      }
    } catch (err) {
      console.log('❌ Error obteniendo trips:', err.message)
      console.log('Status:', err.response?.status)
    }
  }
} catch (err) {
  console.error('❌ Error:', err.message)
}
