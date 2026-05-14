/**
 * Extrae las coordenadas [lat, lng] de un objeto de ruta o viaje,
 * manejando las inconsistencias de formato de la base de datos y la API.
 * 
 * @param {Object} source - Objeto del backend que representa un viaje o ruta
 * @returns {Array} Array de coordenadas [lat, lng], o array vacío si no se encuentra
 */
export function extractRouteCoordinates(source) {
  if (!source) return []
  
  let routePath = []

  // 1. Intenta obtener desde un objeto con coordinates crudas
  if (source.path_route?.coordinates) {
    routePath = source.path_route.coordinates.map(c => [c[1], c[0]])
  } 
  // 2. Intenta parsear desde un JSON stringificado
  else if (typeof source.path_route === 'string') {
    try {
      const parsed = JSON.parse(source.path_route)
      if (parsed.coordinates) {
        routePath = parsed.coordinates.map(c => [c[1], c[0]])
      }
    } catch (e) {
      // String no es JSON válido o no contiene coordenadas
    }
  } 
  // 3. Intenta desde el campo geometry directamente
  else if (source.geometry?.coordinates) {
    routePath = source.geometry.coordinates.map(c => [c[1], c[0]])
  }
  // 4. Intenta desde el campo data.path_route (si viene anidado de la API)
  else if (source.data?.path_route?.coordinates) {
    routePath = source.data.path_route.coordinates.map(c => [c[1], c[0]])
  }
  // 5. Intenta desde el campo data.geometry
  else if (source.data?.geometry?.coordinates) {
    routePath = source.data.geometry.coordinates.map(c => [c[1], c[0]])
  }

  return routePath
}
