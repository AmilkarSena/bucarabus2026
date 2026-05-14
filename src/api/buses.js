import apiClient from './client.js'
import { SYSTEM_USER_ID } from '../constants/system'

/**
 * API de Buses
 * Gestión de la flota de buses
 */

/**
 * Obtener todos los buses
 * @param {boolean} onlyActive - Si es true, solo retorna buses activos
 */
export const getAllBuses = async (onlyActive = false) => {
  const response = await apiClient.get('/buses', {
    params: { active: onlyActive ? 'true' : undefined }
  })
  return response.data
}

/**
 * Obtener buses disponibles (activos y sin conductor asignado)
 */
export const getAvailableBuses = async () => {
  const response = await apiClient.get('/buses/available')
  return response.data
}

/**
 * Obtener bus por placa
 * @param {string} plateNumber - Número de placa del bus
 */
export const getBusByPlate = async (plateNumber) => {
  const response = await apiClient.get(`/buses/${plateNumber}`)
  return response.data
}

/**
 * Obtener estadísticas de buses
 */
export const getBusStats = async () => {
  const response = await apiClient.get('/buses/stats')
  return response.data
}

/**
 * Obtener buses con documentos próximos a vencer
 * @param {number} days - Días para considerar "próximo a vencer"
 */
export const getExpiringBuses = async (days = 30) => {
  const response = await apiClient.get('/buses/expiring', {
    params: { days }
  })
  return response.data
}

/**
 * Crear nuevo bus
 * @param {Object} busData - Datos del bus
 */
export const createBus = async (busData) => {
  const response = await apiClient.post('/buses', busData)
  return response.data
}

/**
 * Actualizar bus existente
 * @param {string} plateNumber - Placa del bus
 * @param {Object} busData - Datos actualizados
 */
export const updateBus = async (plateNumber, busData) => {
  const response = await apiClient.put(`/buses/${plateNumber}`, busData)
  return response.data
}

/**
 * Cambiar estado del bus (activar/desactivar)
 * @param {string} plateNumber - Placa del bus
 * @param {boolean} isActive - Nuevo estado
 * @param {string} userUpdate - Usuario que realiza el cambio
 */
export const toggleBusStatus = async (plateNumber, isActive, userUpdate = SYSTEM_USER_ID) => {
  const response = await apiClient.patch(`/buses/${plateNumber}/status`, {
    is_active: isActive,
    user_update: userUpdate
  })
  return response.data
}

/**
 * Eliminar bus (soft delete)
 * @param {string} plateNumber - Placa del bus
 * @param {string} userUpdate - Usuario que realiza la eliminación
 */
export const deleteBus = async (plateNumber, userUpdate = SYSTEM_USER_ID) => {
  const response = await apiClient.delete(`/buses/${plateNumber}`, {
    data: { user_update: userUpdate }
  })
  return response.data
}

// ─── Catálogos ───────────────────────────────────────────────────────────────

export const getActiveInsuranceTypes = async () => {
  const response = await apiClient.get('/buses/insurance-types')
  return response.data
}

export const getActiveInsurers = async () => {
  const response = await apiClient.get('/buses/insurers')
  return response.data
}

export const getActiveTransitDocTypes = async () => {
  const response = await apiClient.get('/buses/transit-doc-types')
  return response.data
}

// ─── Seguros por bus ─────────────────────────────────────────────────────────

export const getBusInsurance = async (plateNumber) => {
  const response = await apiClient.get(`/buses/${plateNumber}/insurance`)
  return response.data
}

export const addBusInsurance = async (plateNumber, data) => {
  const response = await apiClient.post(`/buses/${plateNumber}/insurance`, data)
  return response.data
}

export const updateInsuranceDocUrl = async (plateNumber, insuranceType, docUrl) => {
  const response = await apiClient.patch(`/buses/${plateNumber}/insurance/${insuranceType}/doc`, { doc_url: docUrl })
  return response.data
}

// ─── Documentos de tránsito por bus ──────────────────────────────────────────

export const getBusTransitDocs = async (plateNumber) => {
  const response = await apiClient.get(`/buses/${plateNumber}/transit-docs`)
  return response.data
}

export const addBusTransitDoc = async (plateNumber, data) => {
  const response = await apiClient.post(`/buses/${plateNumber}/transit-docs`, data)
  return response.data
}

export const updateTransitDocUrl = async (plateNumber, idDoc, docUrl) => {
  const response = await apiClient.patch(`/buses/${plateNumber}/transit-docs/${idDoc}/doc`, { doc_url: docUrl })
  return response.data
}

export default {
  getAllBuses,
  getAvailableBuses,
  getBusByPlate,
  getBusStats,
  getExpiringBuses,
  createBus,
  updateBus,
  toggleBusStatus,
  deleteBus,
  getActiveInsuranceTypes,
  getActiveInsurers,
  getActiveTransitDocTypes,
  getBusInsurance,
  addBusInsurance,
  updateInsuranceDocUrl,
  getBusTransitDocs,
  addBusTransitDoc,
  updateTransitDocUrl
}
