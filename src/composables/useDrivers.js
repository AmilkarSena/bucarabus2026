import { ref, computed, onMounted } from 'vue'
import { useAppStore } from '../stores/app'
import { useDriversStore } from '../stores/drivers'
import { useAuthStore } from '../stores/auth'

export function useDrivers() {
  const appStore = useAppStore()
  const driversStore = useDriversStore()
  const authStore = useAuthStore()

  // ── Estado local ─────────────────────────────────────────────
  const searchQuery        = ref('')
  const availabilityFilter = ref('')
  const categoryFilter     = ref('')
  const showAccountModal   = ref(false)
  const selectedDriverForAccount = ref(null)

  // ── Carga de datos ───────────────────────────────────────────
  onMounted(async () => {
    await driversStore.fetchDrivers()
  })

  // ── Computed ─────────────────────────────────────────────────
  const totalDrivers = computed(() => driversStore.totalDrivers)
  const availableDriversCount = computed(() => driversStore.availableDrivers.length)

  const filteredDrivers = computed(() => {
    let drivers = driversStore.drivers

    if (searchQuery.value) {
      drivers = driversStore.searchDrivers(searchQuery.value)
    }

    if (availabilityFilter.value !== '') {
      const isActive = availabilityFilter.value === 'true'
      drivers = drivers.filter(d => d.is_active === isActive)
    }

    if (categoryFilter.value) {
      drivers = drivers.filter(d => d.license_cat === categoryFilter.value)
    }

    return drivers
  })

  const isSearching = computed(() =>
    !!(searchQuery.value || availabilityFilter.value || categoryFilter.value)
  )

  const canEdit = computed(() => authStore.can('EDIT_DRIVERS'))
  const canCreate = computed(() => authStore.can('CREATE_DRIVERS'))

  // ── Helpers de presentación ──────────────────────────────────
  const formatDate = (dateString) => {
    if (!dateString) return 'N/A'
    return new Date(dateString).toLocaleDateString('es-CO', {
      year: 'numeric', month: 'long', day: 'numeric'
    })
  }

  const getStatusClass = (driver) => {
    if (!driver.is_active) return 'unavailable'
    const s = driver.id_status
    if (s === 1) return 'available'
    if (s === 2) return 'on-trip'
    if (s === 3 || s === 5 || s === 6) return 'resting'
    if (s === 4) return 'sick'
    return 'unavailable'
  }

  const isLicenseValid = (driverId) => driversStore.isLicenseValid(driverId)
  const isLicenseExpiringSoon = (driverId) => driversStore.isLicenseExpiringSoon(driverId)

  const getLicenseStatusClass = (driverId) => {
    if (!isLicenseValid(driverId)) return 'license-expired-text'
    if (isLicenseExpiringSoon(driverId)) return 'license-warning-text'
    return 'license-valid-text'
  }

  // ── Acciones ─────────────────────────────────────────────────
  const openDriverModal = () => appStore.openModal('driver', null)

  const editDriver = (driver) => appStore.openModal('editDriver', driver)

  const viewDriverDetails = (driver) => {
    alert(
      `Detalles del Conductor\n\n` +
      `Nombre: ${driver.name_driver}\n` +
      `Cédula: ${driver.id_driver}\n` +
      `Teléfono: ${driver.phone_driver || 'N/A'}\n` +
      `Email: ${driver.email_driver || 'N/A'}\n` +
      `Dirección: ${driver.address_driver || 'N/A'}\n` +
      `Género: ${driver.gender || 'N/A'}\n\n` +
      `Categoría de licencia: ${driver.license_cat || 'N/A'}\n` +
      `Vencimiento licencia: ${formatDate(driver.license_exp)}\n` +
      `Experiencia: ${driver.experience} años\n\n` +
      `Estado operativo: ${driver.status_name || 'N/A'}\n` +
      `Activo: ${driver.is_active ? 'Sí' : 'No'}`
    )
  }

  const toggleStatus = async (driver) => {
    const newActive = !driver.is_active
    const action = newActive ? 'activar' : 'desactivar'
    if (confirm(`¿Está seguro de que desea ${action} a ${driver.name_driver}?`)) {
      const result = await driversStore.toggleDriverStatus(driver.id_driver, newActive)
      if (!result.success) {
        alert(`Error: ${result.error || 'No se pudo cambiar el estado'}`)
      }
    }
  }

  const openAccountModal = (driver) => {
    selectedDriverForAccount.value = driver
    showAccountModal.value = true
  }

  const onAccountUpdated = async () => {
    await driversStore.fetchDrivers()
  }

  return {
    // State
    searchQuery,
    availabilityFilter,
    categoryFilter,
    showAccountModal,
    selectedDriverForAccount,

    // Computed
    totalDrivers,
    availableDriversCount,
    filteredDrivers,
    isSearching,
    canEdit,
    canCreate,

    // Helpers
    formatDate,
    getStatusClass,
    getLicenseStatusClass,
    isLicenseValid,
    isLicenseExpiringSoon,

    // Acciones
    openDriverModal,
    editDriver,
    viewDriverDetails,
    openAccountModal,
    onAccountUpdated
  }
}
