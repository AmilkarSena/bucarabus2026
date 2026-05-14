import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

export const useAppStore = defineStore('app', () => {
  // Estado
  const currentUser = ref({
    name: 'Admin BucaraBus',
    role: 'Administrator'
  })

  const sidebarOpen = ref(true)
  const isAuthenticated = ref(true) // Para desarrollo, siempre true

  // Estado del mapa
  const mapInstance = ref(null)

  // ── Nuevo flujo: creación de ruta conectando paradas del catálogo ────────
  const isCreatingRoute = ref(false)   // TRUE mientras el usuario está armando el borrador
  const draftStops = ref([])           // [{ id_point, name_point, lat, lng }] en orden
  const draftPath = ref(null)          // [[lat,lng],...] polilínea calculada por OSRM o rectas
  const draftRouteColor = ref('#3b82f6') // Color temporal que el usuario elige en vivo
  const useSmartRouting = ref(true)      // Si es true, usa motor de enrutamiento. Si false, líneas rectas.

  // Estado para creación de puntos de catálogo (independiente de rutas)
  const isCreatingRoutePoint = ref(false)
  const newRoutePointCoords = ref(null)

  // Estado para mostrar todos los puntos del catálogo en el mapa
  const catalogPointsVisible = ref(false)
  const allCatalogPoints = ref([]) // [{ id_point, name_point, lat, lng, point_type, is_checkpoint }]

  // Popup de edición de punto desde el mapa
  // { point: {...}, x: Number, y: Number } | null
  const catalogPointPopup = ref(null)

  // Estado de modales
  const activeModal = ref(null)
  const modalData = ref(null)
  
  // Estado de modales individuales
  const modals = ref({
    driver: false,
    bus: false,
    route: false,
    shift: false,
    shifts: false
  })

  // Getters computados
  const activeBusesCount = computed(() => {
    const busesStore = useBusesStore()
    return busesStore.buses.filter(bus => bus.status_bus).length
  })

  const totalRoutesCount = computed(() => {
    const routesStore = useRoutesStore()
    return Object.keys(routesStore.routes).length
  })

  // Acciones
  const toggleSidebar = () => {
    sidebarOpen.value = !sidebarOpen.value
  }

  const setMapInstance = (map) => {
    mapInstance.value = map
  }

  // ── Acciones del nuevo flujo de creación por paradas ─────────────────────

  /** Activa el modo de creación de ruta; limpia cualquier borrador anterior. */
  const startRouteCreation = () => {
    isCreatingRoute.value = true
    draftStops.value = []
    draftPath.value = null
    useSmartRouting.value = true
  }

  /** Cancela el modo de creación y limpia el borrador. */
  const cancelRouteCreation = () => {
    isCreatingRoute.value = false
    draftStops.value = []
    draftPath.value = null
  }

  /**
   * Agrega una parada al borrador.
   * @param {{ id_point, name_point, lat, lng }} stop
   */
  const addDraftStop = (stop) => {
    draftStops.value.push({ ...stop, useSmartRouting: useSmartRouting.value })
  }

  /** Elimina la última parada del borrador. */
  const undoLastDraftStop = () => {
    draftStops.value.pop()
  }

  /**
   * Elimina una parada del borrador por índice.
   * @param {number} index
   */
  const removeDraftStop = (index) => {
    draftStops.value.splice(index, 1)
  }

  const openModal = (modalType, data = null) => {
    activeModal.value = modalType
    modalData.value = data
    // Actualizar el estado específico del modal
    if (modals.value.hasOwnProperty(modalType)) {
      modals.value[modalType] = true
    }
  }

  const closeModal = (modalType = null) => {
    if (modalType) {
      // Cerrar modal específico
      if (modals.value.hasOwnProperty(modalType)) {
        modals.value[modalType] = false
      }
      if (activeModal.value === modalType) {
        activeModal.value = null
        modalData.value = null
      }
    } else {
      // Cerrar modal activo
      if (activeModal.value && modals.value.hasOwnProperty(activeModal.value)) {
        modals.value[activeModal.value] = false
      }
      activeModal.value = null
      modalData.value = null
    }
  }

  return {
    // Estado
    currentUser,
    sidebarOpen,
    isAuthenticated,
    mapInstance,
    // Nuevo flujo de creación por paradas
    isCreatingRoute,
    draftStops,
    draftPath,
    draftRouteColor,
    useSmartRouting,
    // Creación de puntos de catálogo
    isCreatingRoutePoint,
    newRoutePointCoords,
    catalogPointsVisible,
    allCatalogPoints,
    catalogPointPopup,
    activeModal,
    modalData,
    modals,

    // Getters
    activeBusesCount,
    totalRoutesCount,

    // Acciones
    toggleSidebar,
    setMapInstance,
    // Nuevo flujo de creación por paradas
    startRouteCreation,
    cancelRouteCreation,
    addDraftStop,
    undoLastDraftStop,
    removeDraftStop,
    openModal,
    closeModal
  }
})

// Importar otros stores para evitar dependencias circulares
import { useBusesStore } from './buses'
import { useRoutesStore } from './routes'