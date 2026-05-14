import apiClient from './client.js'

/**
 * Obtener todos los incidentes activos
 */
export const getActiveIncidents = async () => {
  const response = await apiClient.get('/incidents?status=active')
  return response.data
}

/**
 * Resolver un incidente por ID
 */
export const resolveIncident = async (id) => {
  const response = await apiClient.patch(`/incidents/${id}/resolve`)
  return response.data
}

/**
 * Geocodificación inversa: coordenadas → dirección legible
 * Reutiliza el endpoint existente (Photon local → fallback Google)
 */
export const reverseGeocode = async (lat, lng) => {
  try {
    const response = await apiClient.get(`/geocoding/reverse?lat=${lat}&lng=${lng}`)
    return response.data?.name || null
  } catch {
    return null
  }
}
