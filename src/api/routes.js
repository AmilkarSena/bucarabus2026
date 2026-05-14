import apiClient from './client.js'

/**
 * 🗺️ API de Rutas
 */
export const routesApi = {

  /**
   * Obtener cantidad de viajes activos o pendientes de una ruta
   */
  async getActiveTripsCount(id) {
    try {
      const response = await apiClient.get(`/routes/${id}/active-trips-count`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Obtener todas las rutas
   */
  async getAll() {
    try {
      const response = await apiClient.get('/routes')
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Obtener ruta por ID
   */
  async getById(id) {
    try {
      const response = await apiClient.get(`/routes/${id}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Buscar rutas por nombre o descripción
   */
  async search(query) {
    try {
      const response = await apiClient.get('/routes/search', {
        params: { q: query }
      })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Crear nueva ruta
   * @param {Object} routeData - { name, path, color, idCompany, userCreate,
   *                              description?, firstTrip?, lastTrip?,
   *                              departureRouteSign?, returnRouteSign?,
   *                              startArea?, endArea? }
   */
  async create(routeData) {
    try {
      const response = await apiClient.post('/routes', routeData)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Actualizar metadatos de ruta (path_route es inmutable)
   * @param {Object} routeData - { name?, color?, idCompany?, userUpdate?,
   *                              description?, firstTrip?, lastTrip?,
   *                              departureRouteSign?, returnRouteSign? }
   */
  async update(id, routeData) {
    try {
      const response = await apiClient.put(`/routes/${id}`, routeData)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Desactivar ruta (soft-delete: is_active = FALSE)
   * @param {number} id - ID de la ruta
   * @param {number} [userUpdate] - ID del usuario que desactiva
   */
  async delete(id, userUpdate) {
    try {
      const response = await apiClient.delete(`/routes/${id}`, {
        data: userUpdate ? { userUpdate } : undefined
      })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Activar o desactivar ruta manualmente
   * @param {number} id
   * @param {boolean} isActive
   * @param {number} [userUpdate]
   */
  async toggle(id, isActive, userUpdate) {
    try {
      const response = await apiClient.patch(`/routes/${id}/toggle`, {
        isActive,
        userUpdate
      })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Alternar visibilidad de ruta (solo estado local de la UI, no BD)
   */
  async toggleVisibility(id) {
    try {
      const response = await apiClient.patch(`/routes/${id}/visibility`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Obtener distancia de ruta en km
   */
  async getDistance(id) {
    try {
      const response = await apiClient.get(`/routes/${id}/distance`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Obtener todos los puntos asignados a una ruta
   * @param {number} routeId
   */
  async getPoints(routeId) {
    try {
      const response = await apiClient.get(`/routes/${routeId}/points`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Asignar un punto de ruta existente a esta ruta
   * @param {number} routeId
   * @param {Object} pointData - { idPoint, pointOrder, distFromStart?, etaSeconds? }
   */
  async assignPoint(routeId, pointData) {
    try {
      const response = await apiClient.post(`/routes/${routeId}/points`, pointData)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Desasignar un punto de una ruta
   * @param {number} routeId
   * @param {number} pointId
   */
  async unassignPoint(routeId, pointId) {
    try {
      const response = await apiClient.delete(`/routes/${routeId}/points/${pointId}`)
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Reordenar los puntos de una ruta
   * @param {number} routeId
   * @param {Array<{idPoint: number, order: number}>} orderArray
   */
  async reorderPoints(routeId, orderArray) {
    try {
      const response = await apiClient.put(`/routes/${routeId}/points/reorder`, { order: orderArray })
      return response.data
    } catch (error) {
      throw this.handleError(error)
    }
  },

  /**
   * Manejador de errores centralizado
   */
  handleError(error) {
    if (error.response) {
      const errorObj = {
        success: false,
        error:   error.response.data.error || 'Error del servidor',
        message: error.response.data.message,
        code:    error.response.data.code   || null,
        status:  error.response.status
      }
      return errorObj
    } else if (error.request) {
      return {
        success: false,
        error:   'No se pudo conectar con el servidor',
        message: 'Verifica tu conexión o que el servidor esté corriendo'
      }
    } else {
      return {
        success: false,
        error:   'Error en la petición',
        message: error.message
      }
    }
  }
}

export default routesApi
