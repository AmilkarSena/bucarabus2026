import apiClient from './client.js'

/**
 * Asignar conductor a bus
 * assigned_by lo resuelve el backend desde el token JWT
 */
export const assignDriver = async (idBus, idDriver) => {
  const response = await apiClient.post('/assignments', {
    id_bus: idBus,
    id_driver: idDriver
  })
  return response.data
}

/**
 * Desasignar conductor activo (por id_driver)
 * unassigned_by lo resuelve el backend desde el token JWT
 */
export const unassignDriver = async (idDriver) => {
  const response = await apiClient.delete(`/assignments/${idDriver}`)
  return response.data
}

/**
 * Obtener asignación activa de un bus
 */
export const getActiveAssignment = async (idBus) => {
  const response = await apiClient.get(`/assignments/active/${idBus}`)
  return response.data
}

/**
 * Obtener historial de asignaciones de un bus
 */
export const getBusHistory = async (idBus) => {
  const response = await apiClient.get(`/assignments/bus/${idBus}`)
  return response.data
}

export default { assignDriver, unassignDriver, getActiveAssignment, getBusHistory }
