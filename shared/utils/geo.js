/**
 * Utilidades geográficas compartidas entre todas las apps de BucaraBus.
 * Sin dependencias externas — solo matemáticas puras.
 */

/**
 * Fórmula de Haversine: distancia en metros entre dos coordenadas.
 */
export const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371000
  const dLat = (lat2 - lat1) * Math.PI / 180
  const dLon = (lon2 - lon1) * Math.PI / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * Formatea metros a texto legible (ej: "350 m" o "1.2 km").
 */
export const formatDistance = (meters) => {
  if (meters < 1000) return `${Math.round(meters)} m`
  return `${(meters / 1000).toFixed(1)} km`
}

/**
 * Calcula el tiempo estimado de llegada en texto legible.
 * @param {number} meters - Distancia en metros
 * @param {number} speedKmh - Velocidad en km/h (mínimo 20 si es menor)
 */
export const calculateETA = (meters, speedKmh) => {
  if (!speedKmh || speedKmh < 5) speedKmh = 20
  const hours = meters / 1000 / speedKmh
  const minutes = Math.round(hours * 60)
  if (minutes < 1) return '< 1 min'
  if (minutes === 1) return '1 min'
  return `${minutes} min`
}
