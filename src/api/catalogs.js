import apiClient from './client.js'

/**
 * Obtener todas las EPS activas
 */
export const getAllEps = async () => {
  const response = await apiClient.get('/catalogs/eps')
  return response.data
}

/**
 * Obtener todas las ARL activas
 */
export const getAllArl = async () => {
  const response = await apiClient.get('/catalogs/arl')
  return response.data
}

/**
 * Obtener todos los estados de viaje desde la DB
 * Fuente única de verdad para labels, colores e íconos
 */
export const getTripStatuses = async () => {
  const response = await apiClient.get('/catalogs/trip-statuses')
  return response.data
}

/**
 * Obtener todos los roles activos desde la DB
 */
export const getRoles = async () => {
  const response = await apiClient.get('/catalogs/roles')
  return response.data
}

/**
 * Obtener todos los propietarios de buses activos
 */
export const getBusOwners = async () => {
  const response = await apiClient.get('/catalogs/bus-owners')
  return response.data
}

/**
 * Obtener todas las compañías activas
 */
export const getCompanies = async () => {
  const response = await apiClient.get('/catalogs/companies')
  return response.data
}

/**
 * Obtener todas las marcas de buses activas
 */
export const getBrands = async () => {
  const response = await apiClient.get('/catalogs/brands')
  return response.data
}

/**
 * Obtener todos los puntos de ruta disponibles
 */
export const getRoutePoints = async () => {
  const response = await apiClient.get('/catalogs/points')
  return response.data
}

/**
 * Crear un nuevo punto de ruta global
 */
export const createRoutePoint = async (pointData) => {
  const response = await apiClient.post('/catalogs/points', pointData)
  return response.data
}

// =============================================
// Puntos de Ruta - Admin CRUD
// =============================================
export const getAllRoutePointsAdmin = async () => {
  const response = await apiClient.get('/catalogs/points/admin')
  return response.data
}
export const updateRoutePoint = async (id, data) => {
  const response = await apiClient.put(`/catalogs/points/${id}`, data)
  return response.data
}
export const toggleRoutePoint = async (id, isActive) => {
  const response = await apiClient.patch(`/catalogs/points/${id}/toggle`, { is_active: isActive })
  return response.data
}

// =============================================
// EPS - Admin CRUD
// =============================================
export const getAllEpsAdmin = async () => {
  const response = await apiClient.get('/catalogs/eps/admin')
  return response.data
}
export const createEps = async (data) => {
  const response = await apiClient.post('/catalogs/eps', data)
  return response.data
}
export const updateEps = async (id, data) => {
  const response = await apiClient.put(`/catalogs/eps/${id}`, data)
  return response.data
}
export const toggleEps = async (id) => {
  const response = await apiClient.patch(`/catalogs/eps/${id}/toggle`)
  return response.data
}

// =============================================
// ARL - Admin CRUD
// =============================================
export const getAllArlAdmin = async () => {
  const response = await apiClient.get('/catalogs/arl/admin')
  return response.data
}
export const createArl = async (data) => {
  const response = await apiClient.post('/catalogs/arl', data)
  return response.data
}
export const updateArl = async (id, data) => {
  const response = await apiClient.put(`/catalogs/arl/${id}`, data)
  return response.data
}
export const toggleArl = async (id) => {
  const response = await apiClient.patch(`/catalogs/arl/${id}/toggle`)
  return response.data
}

// =============================================
// Marcas - Admin CRUD
// =============================================
export const getAllBrandsAdmin = async () => {
  const response = await apiClient.get('/catalogs/brands/admin')
  return response.data
}
export const createBrand = async (data) => {
  const response = await apiClient.post('/catalogs/brands', data)
  return response.data
}
export const updateBrand = async (id, data) => {
  const response = await apiClient.put(`/catalogs/brands/${id}`, data)
  return response.data
}
export const toggleBrand = async (id) => {
  const response = await apiClient.patch(`/catalogs/brands/${id}/toggle`)
  return response.data
}

// =============================================
// Compañías - Admin CRUD
// =============================================
export const getAllCompaniesAdmin = async () => {
  const response = await apiClient.get('/catalogs/companies/admin')
  return response.data
}
export const createCompany = async (data) => {
  const response = await apiClient.post('/catalogs/companies', data)
  return response.data
}
export const updateCompany = async (id, data) => {
  const response = await apiClient.put(`/catalogs/companies/${id}`, data)
  return response.data
}
export const toggleCompany = async (id) => {
  const response = await apiClient.patch(`/catalogs/companies/${id}/toggle`)
  return response.data
}

// =============================================
// Aseguradoras - Admin CRUD
// =============================================
export const getAllInsurersAdmin = async () => {
  const response = await apiClient.get('/catalogs/insurers/admin')
  return response.data
}
export const createInsurer = async (data) => {
  const response = await apiClient.post('/catalogs/insurers', data)
  return response.data
}
export const updateInsurer = async (id, data) => {
  const response = await apiClient.put(`/catalogs/insurers/${id}`, data)
  return response.data
}
export const toggleInsurer = async (id) => {
  const response = await apiClient.patch(`/catalogs/insurers/${id}/toggle`)
  return response.data
}


// =============================================
// Seguros
// =============================================
export const getAllInsuranceTypesAdmin = () => apiClient.get('/catalogs/insurance-types/admin').then(res => res.data)
export const createInsuranceType = (data) => apiClient.post('/catalogs/insurance-types', data).then(res => res.data)
export const updateInsuranceType = (id, data) => apiClient.put('/catalogs/insurance-types/'+id, data).then(res => res.data)
export const toggleInsuranceType = (id) => apiClient.patch('/catalogs/insurance-types/'+id+'/toggle').then(res => res.data)

// =============================================
// Documentos de Transito
// =============================================
export const getAllTransitDocsAdmin = () => apiClient.get('/catalogs/transit-docs/admin').then(res => res.data)
export const createTransitDoc = (data) => apiClient.post('/catalogs/transit-docs', data).then(res => res.data)
export const updateTransitDoc = (id, data) => apiClient.put('/catalogs/transit-docs/'+id, data).then(res => res.data)
export const toggleTransitDoc = (id) => apiClient.patch('/catalogs/transit-docs/'+id+'/toggle').then(res => res.data)

// =============================================
// Tipos de Incidentes
// =============================================
export const getAllIncidentTypesAdmin = () => apiClient.get('/catalogs/incident-types/admin').then(res => res.data)
export const createIncidentType = (data) => apiClient.post('/catalogs/incident-types', data).then(res => res.data)
export const updateIncidentType = (id, data) => apiClient.put('/catalogs/incident-types/'+id, data).then(res => res.data)
export const toggleIncidentType = (id) => apiClient.patch('/catalogs/incident-types/'+id+'/toggle').then(res => res.data)
