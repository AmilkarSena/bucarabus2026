import { ref, onMounted } from 'vue'
import { getAllEps, getAllArl } from '../api/catalogs.js'
import { useDriversStore } from '../stores/drivers'

/**
 * Composable que orquesta la comunicación con el backend para la gestión de conductores.
 * 
 * Responsabilidades:
 * 1. Gestión de Catálogos de Salud: Recupera y almacena las listas de EPS y ARL del sistema.
 * 2. Operaciones CRUD: Encapsula las llamadas al Store para crear y actualizar conductores.
 * 3. Seguridad de Estado: Gestiona las advertencias de confirmación al desactivar un conductor,
 *    previniendo cambios accidentales que afecten la disponibilidad de personal.
 * 
 * @returns {Object} Listas de salud y métodos de persistencia (saveDriver, handleStatusChange).
 */

// Estado global (caché) para catálogos de salud
const epsList = ref([])
const arlList = ref([])
let catalogsLoaded = false

export function useDriverPersistence() {
  const driversStore = useDriversStore()

  const loadCatalogs = async (forceRefresh = false) => {
    if (catalogsLoaded && !forceRefresh) return
    
    try {
      const [epsResult, arlResult] = await Promise.all([getAllEps(), getAllArl()])
      if (epsResult.success) epsList.value = epsResult.data
      if (arlResult.success) arlList.value = arlResult.data
      
      catalogsLoaded = true
    } catch (error) {
      console.error('Error cargando catálogos:', error)
    }
  }

  // Cargar automáticamente al montar el componente donde se use
  onMounted(() => loadCatalogs())

  /**
   * Guarda un conductor (creación o actualización)
   * @param {Object} driverData - Datos del formulario
   * @param {Boolean} isEditMode - Si es modo edición
   * @param {Number|String} originalId - ID original en caso de edición
   * @returns Promise
   */
  const saveDriver = async (driverData, isEditMode, originalId = null) => {
    if (isEditMode) {
      const result = await driversStore.updateDriver(originalId, driverData)
      if (!result.success) throw new Error(result.error)
      return result
    } else {
      const result = await driversStore.createDriver(driverData)
      if (!result.success) throw new Error(result.error)
      return result
    }
  }

  /**
   * Maneja el cambio del switch de estado Activo/Inactivo en el modal.
   * Llama a PATCH /:id/status de forma inmediata (no espera al submit del formulario)
   * porque fun_update_driver no acepta el campo is_active.
   * @param {Object} formData - Objeto reactivo del formulario
   */
  const handleStatusChange = async (formData) => {
    const newActive = formData.is_active

    const action = newActive ? 'activar' : 'desactivar'
    const confirmed = confirm(
      newActive
        ? '¿Activar este conductor? Podrá volver a ser asignado a rutas.'
        : '⚠️ ¿Desactivar este conductor? No podrá ser asignado a rutas.'
    )

    if (!confirmed) {
      // Revertir el switch visualmente
      formData.is_active = !newActive
      return
    }

    const result = await driversStore.toggleDriverStatus(formData.id_driver, newActive)

    if (!result.success) {
      // Revertir si la API falló
      formData.is_active = !newActive
      alert(`Error al ${action} el conductor: ${result.error || 'Error desconocido'}`)
    }
  }

  return {
    epsList,
    arlList,
    saveDriver,
    handleStatusChange
  }
}
