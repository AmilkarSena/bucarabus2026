import { ref } from 'vue'

/**
 * Composable que gestiona el estado reactivo y el ciclo de vida de los datos en el formulario de buses.
 * 
 * Su responsabilidad única es mantener la integridad de los datos del bus mientras se editan o crean.
 * - Centraliza la estructura inicial del objeto Bus (Schema).
 * - Maneja la carga de datos desde la API hacia la UI, normalizando valores nulos o "SA" (Sin Asignar).
 * - Provee mecanismos para limpiar el formulario al cerrar modales.
 * 
 * @returns {Object} { formData, loadBusData, resetFormData }
 */


// crea un objeto reactivo con la estructura inicial del bus, con valores por defecto
export function useBusForm() {
  const getDefaultFormData = () => ({
    plate_number:   '',
    amb_code:       '',
    code_internal:  '',
    id_company:     '',
    model_year:     null,
    capacity_bus:   null,
    color_bus:      '',
    id_owner:       '',
    id_brand:       null,
    model_name:     '',
    chassis_number: '',
    photo_url:      '',
    gps_device_id:  '',
    color_app:      '#CCCCCC',
    is_active:      true
  })

  const formData = ref(getDefaultFormData())

  const loadBusData = (bus) => {
    console.log('📥 Cargando datos del bus:', bus)
    formData.value = {
      plate_number:   bus.plate_number   || '',
      amb_code:       bus.amb_code       || '',
      code_internal:  bus.code_internal  || '',
      id_company:     bus.id_company     || '',
      model_year:     bus.model_year     || null,
      capacity_bus:   bus.capacity_bus   || null,
      color_bus:      bus.color_bus      || '',
      id_owner:       bus.id_owner       || '',
      id_brand:       bus.id_brand       || null,
      model_name:     bus.model_name     === 'SA' ? '' : (bus.model_name     || ''),
      chassis_number: bus.chassis_number === 'SA' ? '' : (bus.chassis_number || ''),
      photo_url:      bus.photo_url      || '',
      gps_device_id:  bus.gps_device_id  || '',
      color_app:      bus.color_app      || '#CCCCCC',
      is_active:      bus.is_active      ?? true
    }
    console.log('✅ FormData cargado:', formData.value)
  }

  const resetFormData = () => {
    formData.value = getDefaultFormData()
  }

  return {
    formData,
    loadBusData,
    resetFormData
  }
}
