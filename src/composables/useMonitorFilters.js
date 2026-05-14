import { ref, computed } from 'vue'

/**
 * Composable que implementa la lógica de búsqueda y filtrado dinámico para el Monitor.
 * 
 * Permite segmentar la flota activa mediante dos mecanismos:
 * 1. Filtro de Estado Temporal (Chips): Clasifica los buses comparando la hora actual 
 *    de Colombia (UTC-5) contra el rango de tiempo (start_time/end_time) del viaje:
 *    - Activos: El viaje está ocurriendo ahora mismo.
 *    - Programados: El viaje ocurrirá más tarde.
 *    - Finalizados: El viaje ya debería haber terminado según el cronograma.
 * 2. Filtro de Texto: Realiza una búsqueda "fuzzy" sobre el nombre de la ruta, 
 *    la placa del bus o el nombre del conductor.
 * 
 * @param {Ref<Array>} activeRoutesData - Los datos brutos de rutas y buses a filtrar.
 */

export function useMonitorFilters(activeRoutesData) {
  const searchQuery = ref('')
  const statusFilter = ref('activos') // 'activos' | 'programados' | 'finalizados' | 'todos'

  // Convierte string HH:MM:SS a minutos desde medianoche
  const timeToMinutes = (t) => {
    if (!t) return -1
    const parts = String(t).split(':')
    return parseInt(parts[0]) * 60 + parseInt(parts[1])
  }

  // Minutos actuales en Colombia (UTC-5)
  const nowMinutes = () => {
    const str = new Intl.DateTimeFormat('en-CA', {
      timeZone: 'America/Bogota',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false
    }).format(new Date())
    const [h, m] = str.split(':')
    return parseInt(h) * 60 + parseInt(m)
  }

  // Filtrar buses por chip de estado (basado en hora actual vs rango del viaje)
  const filterBusByChip = (bus) => {
    const filter = statusFilter.value
    if (filter === 'todos') return true

    const now   = nowMinutes()
    const start = timeToMinutes(bus.start_time)
    const end   = timeToMinutes(bus.end_time)

    switch (filter) {
      case 'activos':     return start !== -1 && end !== -1 && now >= start && now <= end
      case 'programados': return start !== -1 && now < start
      case 'finalizados': return end   !== -1 && now > end
      default:            return true
    }
  }

  // Filtrar rutas según búsqueda y chip seleccionado
  const filteredRoutes = computed(() => {
    const query = searchQuery.value.toLowerCase().trim()
    const _filter = statusFilter.value // dependencia explícita para Vue

    return activeRoutesData.value.filter(route => {
      // Primero verificar que la ruta tenga buses que pasen el filtro de chip
      const busesEnChip = route.buses.filter(filterBusByChip)
      if (busesEnChip.length === 0) return false

      // Luego aplicar búsqueda de texto
      if (!query) return true
      if (route.name.toLowerCase().includes(query)) return true
      return busesEnChip.some(bus =>
        bus.placa?.toLowerCase().includes(query) ||
        bus.conductor?.toLowerCase().includes(query)
      )
    })
  })

  // Obtener buses filtrados de una ruta (chip + búsqueda)
  const getFilteredBuses = (route) => {
    const query = searchQuery.value.toLowerCase().trim()

    let buses = route.buses.filter(filterBusByChip)

    if (!query) return buses

    // Si la búsqueda coincide con el nombre de la ruta, mostrar todos los buses del chip
    if (route.name.toLowerCase().includes(query)) return buses

    return buses.filter(bus =>
      bus.placa?.toLowerCase().includes(query) ||
      bus.conductor?.toLowerCase().includes(query)
    )
  }

  const handleSearch = () => {
    console.log('🔍 Buscando:', searchQuery.value)
  }

  const clearSearch = () => {
    searchQuery.value = ''
  }

  return {
    searchQuery,
    statusFilter,
    filteredRoutes,
    getFilteredBuses,
    handleSearch,
    clearSearch
  }
}
