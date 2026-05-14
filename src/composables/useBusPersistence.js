import { ref, onMounted } from 'vue'
import { useBusesStore } from './../stores/buses'
import { getBusOwners, getCompanies, getBrands } from './../api/catalogs.js'

/**
 * Composable que orquesta la persistencia de datos y la gestión de catálogos para el módulo de buses.
 * 
 * Este módulo centraliza las operaciones de I/O relacionadas con buses:
 * 1. Carga de Catálogos: Obtiene propietarios, compañías y marcas de forma paralela para optimizar el tiempo de carga.
 * 2. Guardado Inteligente: Diferencia entre creación (POST) y actualización (PUT) de buses, 
 *    asegurando que los datos se normalicen antes de enviarse al servidor.
 * 3. Lógica de Seguridad de Desactivación: Implementa reglas de negocio para impedir desactivar un bus 
 *    si este tiene un conductor asignado actualmente, protegiendo la integridad operativa.
 * 4. Sincronización con el Store: Dispara refrescos del store de Pinia tras cada operación exitosa.
 * 
 * @returns {Object} Catálogos (owners, companies, brands) y métodos de persistencia (saveBus, handleStatusChange).
 */

// Estado global (caché) para catálogos de buses
const busOwners = ref([])
const companies = ref([])
const brands = ref([])
let catalogsLoaded = false

export function useBusPersistence() {
  const busesStore = useBusesStore()

  // Cargar catálogos (solo si no están en caché, o si se fuerza)
  const loadCatalogs = async (forceRefresh = false) => {
    if (catalogsLoaded && !forceRefresh) return
    
    try {
      const [ownersResult, companiesResult, brandsResult] = await Promise.all([
        getBusOwners(),
        getCompanies(),
        getBrands()
      ])
      if (ownersResult.success) busOwners.value = ownersResult.data
      if (companiesResult.success) companies.value = companiesResult.data
      if (brandsResult.success) brands.value = brandsResult.data
      
      catalogsLoaded = true
    } catch (err) {
      console.error('Error al cargar catálogos del bus:', err)
    }
  }

  // Se ejecuta automáticamente al usar el composable
  onMounted(() => {
    loadCatalogs()
  })

  // Validación de estado (switch Activo/Inactivo)
  const handleStatusChange = (formData, originalData) => {
    if (!formData.is_active) {
      if (originalData && originalData.assigned_driver) {
        alert('⚠️ No puedes desactivar este bus porque tiene un conductor asignado actualmente.\n\nPor favor, desasigna al conductor primero desde el módulo de despacho.')
        formData.is_active = true
        return
      }

      const confirmed = confirm('⚠️ ¿Desactivar este bus? No podrá ser asignado a conductores ni rutas.')
      if (!confirmed) {
        formData.is_active = true
      }
    }
  }

  // Guardar / Actualizar Bus
  const saveBus = async (formData, isEditMode, originalData) => {
    const busData = {
      plate_number:   formData.plate_number,
      amb_code:       formData.amb_code,
      code_internal:  formData.code_internal,
      id_company:     formData.id_company,
      model_year:     formData.model_year,
      capacity_bus:   formData.capacity_bus,
      color_bus:      formData.color_bus,
      id_owner:       formData.id_owner,
      id_brand:       formData.id_brand       || null,
      model_name:     formData.model_name?.trim()     || 'SA',
      chassis_number: formData.chassis_number?.trim() || 'SA',
      photo_url:      formData.photo_url    || null,
      gps_device_id:  formData.gps_device_id || null,
      color_app:      formData.color_app     || '#CCCCCC'
    }

    if (isEditMode) {
      const result = await busesStore.updateBus(originalData.plate_number, busData)
      if (!result.success) throw new Error(result.error)
      
      // El estado no se actualiza con updateBus, usar toggleBusStatus
      if (formData.is_active !== originalData.is_active) {
        const statusResult = await busesStore.toggleBusStatus(originalData.plate_number, formData.is_active)
        if (!statusResult.success) {
          // Revertir el switch en la UI si falla
          formData.is_active = originalData.is_active
          throw new Error(statusResult.error || 'No se pudo cambiar el estado del bus.')
        }
      }
    } else {
      const result = await busesStore.createBus(busData)
      if (!result.success) throw new Error(result.error)
    }

    // Recargar la lista completa para obtener id_company, insurance_coverage y
    // transit_doc_coverage que solo vienen del endpoint de lista con JOINs.
    await busesStore.fetchBuses()
  }

  return {
    busOwners,
    companies,
    brands,
    handleStatusChange,
    saveBus
  }
}
