import { ref } from 'vue'
import L from 'leaflet'
import { formatDistance } from '@shared/utils/geo'

/**
 * Composable que gestiona la búsqueda de lugares y geocodificación mediante Nominatim.
 *
 * @param {string}   apiUrl - URL base del servidor de geocodificación.
 * @param {Function} getMap - Función para obtener la instancia del mapa Leaflet.
 */
export function useNominatim(apiUrl, getMap) {
  const searchQuery       = ref('')
  const searchResults     = ref([])
  const showSearchResults = ref(false)
  const selectedDestination = ref(null)
  const destMarker        = ref(null)
  let searchTimeout       = null

  const searchDestination = async () => {
    if (!searchQuery.value || searchQuery.value.length < 2) {
      searchResults.value = []
      return
    }
    clearTimeout(searchTimeout)
    searchTimeout = setTimeout(async () => {
      try {
        const query    = encodeURIComponent(searchQuery.value)
        const baseUrl  = apiUrl.endsWith('/') ? apiUrl.slice(0, -1) : apiUrl
        const response = await fetch(`${baseUrl || ''}/api/geocoding/search?q=${query}`)
        if (!response.ok) throw new Error('Search request failed')
        const data = await response.json()
        if (data.success) {
          searchResults.value     = data.data
          showSearchResults.value = true
        } else {
          searchResults.value = []
        }
      } catch (error) {
        console.error('Error searching:', error)
        searchResults.value = []
      }
    }, 500)
  }

  const selectDestination = (destination, onSelected) => {
    selectedDestination.value = destination
    searchQuery.value         = destination.name
    showSearchResults.value   = false

    const map = getMap()
    if (!map) return

    if (destMarker.value) map.removeLayer(destMarker.value)

    destMarker.value = L.circleMarker([destination.lat, destination.lng], {
      radius: 12, color: 'white', weight: 3, fillColor: '#f97316', fillOpacity: 1
    })
      .bindTooltip(`📍 ${destination.name}`, { permanent: false, direction: 'top', offset: [0, -10], className: 'dest-tooltip' })
      .bindPopup(`<strong>Destino:</strong><br>${destination.name}`)
      .addTo(map)
      .openPopup()

    map.setView([destination.lat, destination.lng], 16)
    if (onSelected) onSelected()
  }

  const clearDestination = (onCleared) => {
    searchQuery.value         = ''
    selectedDestination.value = null
    searchResults.value       = []
    showSearchResults.value   = false

    const map = getMap()
    if (map && destMarker.value) { map.removeLayer(destMarker.value); destMarker.value = null }
    if (onCleared) onCleared()
  }

  return { searchQuery, searchResults, showSearchResults, selectedDestination, searchDestination, selectDestination, clearDestination }
}
