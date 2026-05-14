import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from '../api/client'

export const useDriversStore = defineStore('drivers', () => {
  // =============================================
  // STATE
  // =============================================
  const drivers = ref([])
  const loading = ref(false)
  const error = ref(null)

  // =============================================
  // GETTERS (COMPUTED)
  // =============================================
  const totalDrivers = computed(() => drivers.value.length)

  const availableDrivers = computed(() => 
    drivers.value.filter(driver => driver.id_status === 1 && driver.is_active)
  )

  const unavailableDrivers = computed(() => 
    drivers.value.filter(driver => driver.id_status !== 1 || !driver.is_active)
  )

  const averageExperience = computed(() => {
    if (drivers.value.length === 0) return 0
    const total = drivers.value.reduce((sum, driver) => sum + (driver.experience || 0), 0)
    return (total / drivers.value.length).toFixed(1)
  })

  const driversByCategory = computed(() => {
    return drivers.value.reduce((acc, driver) => {
      const cat = driver.license_cat || 'Sin categoría'
      acc[cat] = (acc[cat] || 0) + 1
      return acc
    }, {})
  })

  const expiredLicenses = computed(() => {
    const today = new Date()
    return drivers.value.filter(driver => {
      if (!driver.license_exp) return false
      const expDate = new Date(driver.license_exp)
      return expDate < today
    })
  })

  const expiringSoonLicenses = computed(() => {
    const today = new Date()
    const thirtyDaysFromNow = new Date(today.getTime() + (30 * 24 * 60 * 60 * 1000))
    
    return drivers.value.filter(driver => {
      if (!driver.license_exp) return false
      const expDate = new Date(driver.license_exp)
      return expDate > today && expDate <= thirtyDaysFromNow
    })
  })

  // =============================================
  // ACTIONS
  // =============================================

  /**
   * Obtener todos los conductores
   */
  async function fetchDrivers() {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Iniciando fetchDrivers...')
      const response = await apiClient.get('/drivers')
      
      console.log('📥 Respuesta completa:', response)
      console.log('📊 response.data:', response.data)
      
      // Si la respuesta tiene data.data (formato del backend)
      const driversData = response.data.data || response.data
      
      console.log('📋 driversData:', driversData)
      console.log('📏 Cantidad de conductores:', driversData.length)
      
      // Mapear campos de BD a formato frontend
      drivers.value = driversData.map(mapDriverFromDB)
      
      console.log('✅ Conductores cargados:', drivers.value.length)
      console.log('👥 Conductores mapeados:', drivers.value)
      return { success: true, data: drivers.value }
    } catch (err) {
      console.error('❌ Error al obtener conductores:', err)
      console.error('📛 Error response:', err.response)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear nuevo conductor
   */
  async function createDriver(driverData) {
    loading.value = true
    error.value = null

    try {
      const payload = {
        id_driver:         driverData.id_driver,
        name_driver:       driverData.name_driver,
        address_driver:    driverData.address_driver || null,
        phone_driver:      driverData.phone_driver   || null,
        email_driver:      driverData.email_driver   || null,
        birth_date:        driverData.birth_date     || null,
        gender_driver:     driverData.gender_driver  || 'SA',
        license_cat:       driverData.license_cat    || null,
        license_exp:       driverData.license_exp,
        id_eps:            driverData.id_eps         || null,
        id_arl:            driverData.id_arl         || null,
        blood_type:        driverData.blood_type     || 'SA',
        emergency_contact: driverData.emergency_contact || null,
        emergency_phone:   driverData.emergency_phone   || null,
        date_entry:        driverData.date_entry     || null,
        id_status:         driverData.id_status      || 1
      }
      
      const response = await apiClient.post('/drivers', payload)

      if (!response.data.success) {
        throw new Error(response.data.message || 'Error al crear conductor')
      }

      await fetchDrivers()

      return { 
        success: true, 
        message: response.data.message,
        id_driver: response.data.data?.id_driver
      }
    } catch (err) {
      console.error('❌ Error al crear conductor:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Actualizar conductor existente
   */
  async function updateDriver(driverId, driverData) {
    loading.value = true
    error.value = null

    try {
      const payload = {
        name_driver:       driverData.name_driver,
        address_driver:    driverData.address_driver    || null,
        phone_driver:      driverData.phone_driver      || null,
        email_driver:      driverData.email_driver      || null,
        birth_date:        driverData.birth_date        || null,
        gender_driver:     driverData.gender_driver     || 'SA',
        license_cat:       driverData.license_cat       || null,
        license_exp:       driverData.license_exp,
        id_eps:            driverData.id_eps            || null,
        id_arl:            driverData.id_arl            || null,
        blood_type:        driverData.blood_type        || 'SA',
        emergency_contact: driverData.emergency_contact || null,
        emergency_phone:   driverData.emergency_phone   || null,
        date_entry:        driverData.date_entry        || null,
        id_status:         driverData.id_status         || 1
      }
      
      const response = await apiClient.put(`/drivers/${driverId}`, payload)

      if (!response.data.success) {
        throw new Error(response.data.message || 'Error al actualizar conductor')
      }

      await fetchDrivers()

      return { 
        success: true, 
        message: response.data.message 
      }
    } catch (err) {
      console.error('❌ Error al actualizar conductor:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Eliminar conductor
   */
  async function deleteDriver(driverId) {
    loading.value = true
    error.value = null

    try {
      const response = await apiClient.delete(`/drivers/${driverId}`)

      if (!response.data.success) {
        throw new Error(response.data.message || 'Error al eliminar conductor')
      }

      drivers.value = drivers.value.filter(d => d.id_driver !== driverId)

      return { 
        success: true, 
        message: response.data.message 
      }
    } catch (err) {
      console.error('❌ Error al eliminar conductor:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Cambiar disponibilidad del conductor
   */
  async function toggleDriverStatus(driverId, isActive) {
    const driver = drivers.value.find(d => d.id_driver === driverId)
    if (!driver) {
      return { success: false, error: 'Conductor no encontrado' }
    }

    try {
      const response = await apiClient.patch(`/drivers/${driverId}/status`, {
        is_active: isActive
      })

      if (response.data.success) {
        driver.is_active = isActive
      }

      return response.data
    } catch (err) {
      console.error('❌ Error al cambiar estado:', err)
      return { success: false, error: err.response?.data?.message || err.message }
    }
  }

  /**
   * Buscar conductores
   */
  function searchDrivers(query) {
    if (!query) return drivers.value

    const searchTerm = query.toLowerCase()
    return drivers.value.filter(driver => 
      driver.name_driver?.toLowerCase().includes(searchTerm) ||
      driver.id_driver?.toString().includes(searchTerm) ||
      driver.phone_driver?.toString().includes(searchTerm) ||
      driver.email_driver?.toLowerCase().includes(searchTerm)
    )
  }

  function getDriverById(driverId) {
    return drivers.value.find(d => d.id_driver === driverId)
  }

  /**
   * Vincular conductor con usuario existente
   */
  async function linkDriverAccount(idDriver, idUser) {
    try {
      const response = await apiClient.post(`/drivers/${idDriver}/account`, { id_user: idUser })
      if (!response.data.success) {
        return { success: false, error: response.data.message }
      }
      // Actualizar el conductor en el store local
      const idx = drivers.value.findIndex(d => d.id_driver === idDriver)
      if (idx !== -1 && response.data.data) {
        drivers.value[idx] = mapDriverFromDB(response.data.data)
      }
      return { success: true, message: response.data.message }
    } catch (err) {
      console.error('❌ Error al vincular cuenta:', err)
      return { success: false, error: err.response?.data?.message || err.message }
    }
  }

  /**
   * Desvincular cuenta del conductor
   */
  async function unlinkDriverAccount(idDriver) {
    try {
      const response = await apiClient.delete(`/drivers/${idDriver}/account`)
      if (!response.data.success) {
        return { success: false, error: response.data.message }
      }
      // Actualizar el conductor en el store local (id_user = null)
      const idx = drivers.value.findIndex(d => d.id_driver === idDriver)
      if (idx !== -1 && response.data.data) {
        drivers.value[idx] = mapDriverFromDB(response.data.data)
      }
      return { success: true, message: response.data.message }
    } catch (err) {
      console.error('❌ Error al desvincular cuenta:', err)
      return { success: false, error: err.response?.data?.message || err.message }
    }
  }

  /**
   * Validar si la licencia está vigente
   */
  function isLicenseValid(driverId) {
    const driver = drivers.value.find(d => d.id_driver === driverId)
    if (!driver || !driver.license_exp) return false

    const today = new Date()
    const expDate = new Date(driver.license_exp)
    return expDate > today
  }

  function isLicenseExpiringSoon(driverId) {
    const driver = drivers.value.find(d => d.id_driver === driverId)
    if (!driver || !driver.license_exp) return false

    const today = new Date()
    const expDate = new Date(driver.license_exp)
    const thirtyDaysFromNow = new Date(today.getTime() + (30 * 24 * 60 * 60 * 1000))

    return expDate > today && expDate <= thirtyDaysFromNow
  }

  function getDaysUntilExpiration(driverId) {
    const driver = drivers.value.find(d => d.id_driver === driverId)
    if (!driver || !driver.license_exp) return null

    const today = new Date()
    const expDate = new Date(driver.license_exp)
    const diffTime = expDate - today
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

    return diffDays
  }

  // =============================================
  // HELPER FUNCTIONS
  // =============================================

  /**
   * Mapear datos de BD a formato frontend
   * Mantener campos en inglés para consistencia con backend
   */
  function mapDriverFromDB(dbDriver) {
    return {
      id_driver:         dbDriver.id_driver,
      name_driver:       dbDriver.name_driver,
      address_driver:    dbDriver.address_driver,
      phone_driver:      dbDriver.phone_driver,
      email_driver:      dbDriver.email_driver,
      birth_date:        dbDriver.birth_date,
      gender_driver:     dbDriver.gender_driver,
      license_cat:       dbDriver.license_cat,
      license_exp:       dbDriver.license_exp,
      id_eps:            dbDriver.id_eps,
      id_arl:            dbDriver.id_arl,
      blood_type:        dbDriver.blood_type,
      emergency_contact: dbDriver.emergency_contact,
      emergency_phone:   dbDriver.emergency_phone,
      date_entry:        dbDriver.date_entry,
      id_status:         dbDriver.id_status,
      status_name:       dbDriver.status_name,
      is_active:         dbDriver.is_active,
      photo_driver:      dbDriver.photo_driver,
      created_at:        dbDriver.created_at,
      updated_at:        dbDriver.updated_at,
      user_create:       dbDriver.user_create,
      user_update:       dbDriver.user_update,
      id_user:           dbDriver.id_user ?? null,
      experience:        calculateExperience(dbDriver.date_entry)
    }
  }

  /**
   * Calcular años de experiencia
   */
  function calculateExperience(dateEntry) {
    if (!dateEntry) return 0
    
    const entryDate = new Date(dateEntry)
    const today = new Date()
    const diffTime = today - entryDate
    const diffYears = diffTime / (1000 * 60 * 60 * 24 * 365.25)
    
    return Math.max(0, Math.floor(diffYears))
  }

  // =============================================
  // RETURN
  // =============================================
  return {
    // State
    drivers,
    loading,
    error,

    // Getters
    totalDrivers,
    availableDrivers,
    unavailableDrivers,
    averageExperience,
    driversByCategory,
    expiredLicenses,
    expiringSoonLicenses,

    // Actions
    fetchDrivers,
    createDriver,
    updateDriver,
    deleteDriver,
    toggleDriverStatus,
    searchDrivers,
    getDriverById,
    isLicenseValid,
    isLicenseExpiringSoon,
    getDaysUntilExpiration,
    linkDriverAccount,
    unlinkDriverAccount
  }
})