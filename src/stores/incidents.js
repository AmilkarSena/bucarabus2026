import { defineStore } from 'pinia'
import { ref } from 'vue'
import { getActiveIncidents, resolveIncident, reverseGeocode } from '../api/incidents'

export const useIncidentsStore = defineStore('incidents', () => {
  const activeIncidents = ref([])
  const loading = ref(false)
  const error = ref(null)

  // Enriquecer un incidente con su dirección (no bloqueante)
  const enrichWithAddress = async (incident) => {
    if (incident.address || !incident.lat || !incident.lng) return
    const address = await reverseGeocode(incident.lat, incident.lng)
    if (address) {
      incident.address = address
    }
  }

  const fetchActiveIncidents = async () => {
    loading.value = true
    try {
      const result = await getActiveIncidents()
      if (result.success) {
        activeIncidents.value = result.data || []
        // Resolver direcciones en paralelo (no bloqueante)
        activeIncidents.value.forEach(i => enrichWithAddress(i))
      }
    } catch (err) {
      error.value = 'Error al cargar incidentes activos'
      console.error(err)
    } finally {
      loading.value = false
    }
  }

  const markAsResolved = async (id) => {
    try {
      const result = await resolveIncident(id)
      if (result.success) {
        // Optimistic update
        removeIncident(id)
        return true
      }
      return false
    } catch (err) {
      console.error('Error resolviendo incidente:', err)
      return false
    }
  }

  // Métodos para actualizar desde WebSockets
  const addIncident = (incident) => {
    // Evitar duplicados
    if (!activeIncidents.value.find(i => i.id === incident.id)) {
      activeIncidents.value.push(incident)
      enrichWithAddress(incident)
    }
  }

  const removeIncident = (id) => {
    activeIncidents.value = activeIncidents.value.filter(i => i.id !== id)
  }

  return {
    activeIncidents,
    loading,
    error,
    fetchActiveIncidents,
    markAsResolved,
    addIncident,
    removeIncident
  }
})
