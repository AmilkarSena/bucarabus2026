import { ref } from 'vue'
import routesApi from '../api/routes'

export function useRouteValidation() {
  const errors = ref({})

  const validateForm = (formData, isEdit) => {
    errors.value = {}

    if (!formData.name?.trim()) {
      errors.value.name = 'El nombre de ruta es obligatorio'
    }

    if (!formData.idCompany || formData.idCompany < 1) {
      errors.value.idCompany = 'El ID de la empresa es obligatorio'
    }

    // Validar horarios (firstTrip < lastTrip)
    if (formData.firstTrip && formData.lastTrip) {
      if (formData.firstTrip >= formData.lastTrip) {
        errors.value.lastTrip = 'El último viaje debe ser después del primer viaje'
      }
    }

    // Solo validar path en modo creación
    if (!isEdit && (!formData.path || formData.path.length < 2)) {
      errors.value.path = 'La ruta debe tener al menos 2 puntos'
      alert('Por favor dibuja la ruta en el mapa con al menos 2 puntos')
    }

    return Object.keys(errors.value).length === 0
  }

  const validateStatusChange = async (isActive, isEdit, routeId) => {
    // Solo validar si estamos desactivando una ruta que ya existe en edición
    if (!isActive && isEdit && routeId) {
      try {
        const response = await routesApi.getActiveTripsCount(routeId)
        if (response && response.success && response.count > 0) {
          alert(`No se puede inactivar la ruta porque tiene ${response.count} viaje(s) pendiente(s), asignado(s) o en curso.`)
          return false
        }
      } catch (error) {
        console.error('Error al validar la inactivación:', error)
        alert('Error de conexión al validar si la ruta puede ser inactivada.')
        return false
      }
    }
    return true
  }

  return {
    errors,
    validateForm,
    validateStatusChange
  }
}
