import { ref, computed, onMounted } from 'vue'
import { getCompanies } from '../api/catalogs'
import { useAppStore } from '../stores/app'
import { useBusesStore } from '../stores/buses'
import { useDriversStore } from '../stores/drivers'
import { useAuthStore } from '../stores/auth'

export function useFleet() {
  const appStore = useAppStore()
  const busesStore = useBusesStore()
  const driversStore = useDriversStore()
  const authStore = useAuthStore()

  // Estado local
  const searchQuery = ref('')
  const availabilityFilter = ref('true')
  const companyFilter = ref('')
  const showComplianceModal = ref(false)
  const initialComplianceSection = ref('insurance')
  const selectedBusPlate = ref('')
  const companies = ref([])

  // Cargar datos
  const loadData = async () => {
    await busesStore.fetchBuses()
    await driversStore.fetchDrivers()
    try {
      const res = await getCompanies()
      if (res?.success) companies.value = res.data
    } catch (e) {
      console.error('Error cargando empresas:', e)
    }
  }

  onMounted(loadData)

  // Helpers
  const getCompanyName = (companyId) => {
    const found = companies.value.find(c => c.id_company === companyId)
    return found ? found.company_name : 'Desconocida'
  }

  // Computed properties
  const totalBuses = computed(() => busesStore.buses.length)
  const availableBusesCount = computed(() => busesStore.availableBuses.length)
  const totalCapacity = computed(() => busesStore.totalCapacity)

  const filteredBuses = computed(() => {
    let buses = busesStore.buses

    if (searchQuery.value) {
      const query = searchQuery.value.toLowerCase()
      buses = buses.filter(bus =>
        bus.plate_number?.toLowerCase().includes(query) ||
        bus.amb_code?.toLowerCase().includes(query) ||
        getCompanyName(bus.id_company).toLowerCase().includes(query)
      )
    }

    if (availabilityFilter.value !== '') {
      const isActive = availabilityFilter.value === 'true'
      buses = buses.filter(bus => bus.is_active === isActive)
    }

    if (companyFilter.value) {
      buses = buses.filter(bus => bus.id_company === parseInt(companyFilter.value))
    }

    return buses
  })

  // Métodos para modales
  const openComplianceModal = (plate) => {
    selectedBusPlate.value = plate
    initialComplianceSection.value = 'insurance'
    showComplianceModal.value = true
  }

  const openBusModal = () => {
    appStore.openModal('bus', null)
  }

  const editBus = (bus) => {
    appStore.openModal('editBus', bus)
  }

  return {
    // State (Refs)
    searchQuery,
    availabilityFilter,
    companyFilter,
    showComplianceModal,
    initialComplianceSection,
    selectedBusPlate,
    companies,
    
    // Data from stores
    drivers: computed(() => driversStore.drivers),
    canEdit: computed(() => authStore.can('EDIT_BUSES')),
    busesStore,

    // Computed
    totalBuses,
    availableBusesCount,
    totalCapacity,
    filteredBuses,
    // Se considera búsqueda si el query no está vacío, si el filtro no es el por defecto (Activos) o si hay empresa seleccionada
    isSearching: computed(() => !!(searchQuery.value || availabilityFilter.value !== 'true' || companyFilter.value)),

    // Actions
    openComplianceModal,
    openBusModal,
    editBus,
    loadData
  }
}
