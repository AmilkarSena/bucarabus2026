import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { getTripStatuses } from '../api/catalogs.js'

// Reglas de negocio: qué operaciones permite cada estado (ver tab_trip_statuses)
const DELETABLE_STATUSES   = [1, 2] // pendiente, asignado
const CANCELLABLE_STATUSES = [3]    // activo
const IMMUTABLE_STATUSES   = [4, 5] // completado, cancelado

/**
 * Store para catálogos de la aplicación.
 * Los estados de viaje se cargan una vez desde la API y se usan en toda la app.
 * Esto evita duplicar colores e íconos en el código JS.
 */
export const useCatalogsStore = defineStore('catalogs', () => {
  // Estado
  const tripStatuses = ref([])   // Array de { id_status, status_name, color_hex, icon }
  const loading = ref(false)
  const error = ref(null)

  // Mapa indexado por id_status para acceso O(1)
  const statusMap = computed(() => {
    const map = {}
    tripStatuses.value.forEach(s => { map[s.id_status] = s })
    return map
  })

  // ── Getters ────────────────────────────────────────────────

  /** status_name del estado desde la DB, ej. 'Activo' */
  function getStatusName(idStatus) {
    return statusMap.value[idStatus]?.status_name ?? 'Desconocido'
  }

  /** Color hexadecimal del estado */
  function getStatusColor(idStatus) {
    return statusMap.value[idStatus]?.color_hex ?? '#000000'
  }

  /** Ícono emoji del estado */
  function getStatusIcon(idStatus) {
    return statusMap.value[idStatus]?.icon ?? '❓'
  }

  /** Objeto completo con toda la info de un estado */
  function getStatusInfo(idStatus) {
    const s = statusMap.value[idStatus]
    if (!s) {
      return { id_status: idStatus, status_name: 'Desconocido', color_hex: '#000000', icon: '❓', valid: false }
    }
    return {
      ...s,
      deletable:   DELETABLE_STATUSES.includes(idStatus),
      cancellable: CANCELLABLE_STATUSES.includes(idStatus),
      immutable:   IMMUTABLE_STATUSES.includes(idStatus),
      valid: true
    }
  }

  /** Array de todos los estados para selects/dropdowns */
  const allStatuses = computed(() => tripStatuses.value.map(s => ({
    value: s.id_status,
    status_name: s.status_name,
    color: s.color_hex,
    icon:  s.icon
  })))

  // ── Acciones ───────────────────────────────────────────────

  async function fetchTripStatuses() {
    if (tripStatuses.value.length > 0) return   // ya cargados

    loading.value = true
    error.value = null
    try {
      const result = await getTripStatuses()
      if (result.success) {
        tripStatuses.value = result.data
      } else {
        error.value = result.message ?? 'Error al cargar estados de viaje'
      }
    } catch (err) {
      console.error('Error cargando trip-statuses:', err)
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  return {
    // Estado
    tripStatuses,
    loading,
    error,

    // Getters
    statusMap,
    allStatuses,
    getStatusName,
    getStatusColor,
    getStatusIcon,
    getStatusInfo,

    // Acciones
    fetchTripStatuses
  }
})
