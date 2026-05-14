import apiClient from './client'

/**
 * Geocodificación inversa: coordenadas → nombre de calle
 * Llama al proxy del backend para no exponer la API key en el frontend.
 * @param {number} lat
 * @param {number} lng
 * @returns {Promise<string|null>} Nombre sugerido o null si no se encontró
 */
export const reverseGeocode = async (lat, lng) => {
  try {
    const res = await apiClient.get('/geocoding/reverse', { params: { lat, lng } })
    return res.data?.name || null
  } catch (err) {
    console.warn('⚠️ reverseGeocode falló silenciosamente:', err?.message)
    return null
  }
}

/**
 * Snap to road: ajusta coordenadas al punto más cercano en una calle real
 * @param {number} lat
 * @param {number} lng
 * @returns {Promise<Object|null>} Objeto con las coordenadas ajustadas
 */
export const snapToRoad = async (lat, lng) => {
  try {
    const res = await apiClient.get('/geocoding/snap', { params: { lat, lng } })
    return res.data
  } catch (err) {
    console.warn('⚠️ snapToRoad falló silenciosamente:', err?.message)
    return null
  }
}
