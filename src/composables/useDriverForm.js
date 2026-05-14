import { ref, computed } from 'vue'

/**
 * Composable que gestiona el estado y la lógica de negocio compleja del formulario de conductores.
 * 
 * Además de manejar el esquema de datos (schema), este módulo implementa reglas legales de tránsito:
 * 1. Cálculo de Edad: Determina la edad exacta para validar requisitos mínimos (18 años).
 * 2. Vigencia de Licencia Proyectada: Calcula automáticamente la fecha máxima de renovación permitida:
 *    - Menores de 60 años: Renovación cada 3 años.
 *    - Mayores de 60 años: Renovación anual por seguridad vial.
 * 3. Normalización de Datos: Limpia formatos de fecha ISO para su uso en inputs de tipo date.
 * 
 * @returns {Object} Estado reactivo y helpers de cálculo de edad/licencia.
 */

export function useDriverForm() {
  // Helper para fecha
  const getTodayDate = () => new Date().toISOString().split('T')[0]

  // Datos por defecto
  const getDefaultFormData = () => ({
    id_driver: null,
    name_driver: '',
    address_driver: '',
    phone_driver: '',
    email_driver: '',
    birth_date: '',
    gender_driver: 'SA',
    license_cat: '',
    license_exp: '',
    id_eps: '',
    id_arl: '',
    blood_type: 'SA',
    emergency_contact: '',
    emergency_phone: '',
    date_entry: getTodayDate(),
    id_status: 1,
    is_active: true,
    photo_driver: ''
  })

  // Estado reactivo del formulario
  const formData = ref(getDefaultFormData())

  // Fechas calculadas generales
  const today = computed(() => getTodayDate())
  const minLicenseDate = computed(() => {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    return tomorrow.toISOString().split('T')[0]
  })

  // =============================================
  // HELPERS PARA EDAD Y LICENCIA
  // =============================================

  /**
   * Calcular edad a partir de fecha de nacimiento
   */
  const calculateAge = (fechaNacimiento) => {
    if (!fechaNacimiento) return null
    const birth = new Date(fechaNacimiento)
    const today = new Date()
    let age = today.getFullYear() - birth.getFullYear()
    const monthDiff = today.getMonth() - birth.getMonth()
    
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
      age--
    }
    
    return age
  }

  /**
   * Calcular fecha máxima de vencimiento de licencia según edad
   * Menores de 60: 3 años
   * 60 años o más: 1 año
   */
  const calculateMaxLicenseExpDate = (fechaNacimiento) => {
    if (!fechaNacimiento) return null
    
    const age = calculateAge(fechaNacimiento)
    if (age === null || age < 18) return null // No válida si es menor de 18
    
    const today = new Date()
    const maxExp = new Date(today)
    
    // Agregar años según edad
    const yearsToAdd = age < 60 ? 3 : 1
    maxExp.setFullYear(maxExp.getFullYear() + yearsToAdd)
    
    return maxExp.toISOString().split('T')[0]
  }

  /**
   * Obtener mensaje sobre vigencia de licencia
   */
  const getLicenseValidityMessage = (fechaNacimiento) => {
    const age = calculateAge(fechaNacimiento)
    if (!age) return ''
    
    return age < 60 
      ? `Licencia válida por 3 años (menor de 60 años)`
      : `Licencia válida por 1 año (60 años o más)`
  }

  // =============================================
  // CARGA Y RESETEO
  // =============================================

  const loadDriverData = (driver) => {
    const fmt = (d) => d ? d.split('T')[0] : ''
    formData.value = {
      id_driver:         driver.id_driver || null,
      name_driver:       driver.name_driver || '',
      address_driver:    driver.address_driver || '',
      phone_driver:      driver.phone_driver || '',
      email_driver:      driver.email_driver || '',
      birth_date:        fmt(driver.birth_date),
      gender_driver:     driver.gender_driver || 'SA',
      license_cat:       driver.license_cat || '',
      license_exp:       fmt(driver.license_exp),
      id_eps:            driver.id_eps || '',
      id_arl:            driver.id_arl || '',
      blood_type:        driver.blood_type || 'SA',
      emergency_contact: driver.emergency_contact || '',
      emergency_phone:   driver.emergency_phone || '',
      date_entry:        fmt(driver.date_entry) || getTodayDate(),
      id_status:         driver.id_status || 1,
      is_active:         driver.is_active ?? true,
      photo_driver:      driver.photo_driver || '',
      updated_at:        driver.updated_at
    }
  }

  const resetFormData = () => {
    formData.value = getDefaultFormData()
  }

  return {
    formData,
    today,
    minLicenseDate,
    calculateAge,
    calculateMaxLicenseExpDate,
    getLicenseValidityMessage,
    loadDriverData,
    resetFormData
  }
}
