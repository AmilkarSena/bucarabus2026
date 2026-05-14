import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as catalogsApi from '../api/catalogs.js'

export const useCatalogsAdminStore = defineStore('catalogsAdmin', () => {
  const eps = ref([])
  const arl = ref([])
  const brands = ref([])
  const companies = ref([])
  const insurers = ref([])
  const loading = ref(false)
  const error = ref(null)

  // =============================================
  // EPS
  // =============================================
  const fetchEps = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllEpsAdmin()
      eps.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar EPS'
    } finally {
      loading.value = false
    }
  }

  const createEps = async (data) => {
    const result = await catalogsApi.createEps(data)
    if (result.success) eps.value.push(result.data)
    return result
  }

  const updateEps = async (id, data) => {
    const result = await catalogsApi.updateEps(id, data)
    if (result.success) {
      const idx = eps.value.findIndex(e => e.id_eps === id)
      if (idx !== -1) eps.value[idx] = result.data
    }
    return result
  }

  const toggleEps = async (id) => {
    const result = await catalogsApi.toggleEps(id)
    if (result.success) {
      const idx = eps.value.findIndex(e => e.id_eps === id)
      if (idx !== -1) eps.value[idx] = result.data
    }
    return result
  }

  // =============================================
  // ARL
  // =============================================
  const fetchArl = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllArlAdmin()
      arl.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar ARL'
    } finally {
      loading.value = false
    }
  }

  const createArl = async (data) => {
    const result = await catalogsApi.createArl(data)
    if (result.success) arl.value.push(result.data)
    return result
  }

  const updateArl = async (id, data) => {
    const result = await catalogsApi.updateArl(id, data)
    if (result.success) {
      const idx = arl.value.findIndex(a => a.id_arl === id)
      if (idx !== -1) arl.value[idx] = result.data
    }
    return result
  }

  const toggleArl = async (id) => {
    const result = await catalogsApi.toggleArl(id)
    if (result.success) {
      const idx = arl.value.findIndex(a => a.id_arl === id)
      if (idx !== -1) arl.value[idx] = result.data
    }
    return result
  }

  // =============================================
  // Marcas
  // =============================================
  const fetchBrands = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllBrandsAdmin()
      brands.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar marcas'
    } finally {
      loading.value = false
    }
  }

  const createBrand = async (data) => {
    const result = await catalogsApi.createBrand(data)
    if (result.success) brands.value.push(result.data)
    return result
  }

  const updateBrand = async (id, data) => {
    const result = await catalogsApi.updateBrand(id, data)
    if (result.success) {
      const idx = brands.value.findIndex(b => b.id_brand === id)
      if (idx !== -1) brands.value[idx] = result.data
    }
    return result
  }

  const toggleBrand = async (id) => {
    const result = await catalogsApi.toggleBrand(id)
    if (result.success) {
      const idx = brands.value.findIndex(b => b.id_brand === id)
      if (idx !== -1) brands.value[idx] = result.data
    }
    return result
  }

  // =============================================
  // Compañías
  // =============================================
  const fetchCompanies = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllCompaniesAdmin()
      companies.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar compañías'
    } finally {
      loading.value = false
    }
  }

  const createCompany = async (data) => {
    const result = await catalogsApi.createCompany(data)
    if (result.success) companies.value.push(result.data)
    return result
  }

  const updateCompany = async (id, data) => {
    const result = await catalogsApi.updateCompany(id, data)
    if (result.success) {
      const idx = companies.value.findIndex(c => c.id_company === id)
      if (idx !== -1) companies.value[idx] = result.data
    }
    return result
  }

  const toggleCompany = async (id) => {
    const result = await catalogsApi.toggleCompany(id)
    if (result.success) {
      const idx = companies.value.findIndex(c => c.id_company === id)
      if (idx !== -1) companies.value[idx] = result.data
    }
    return result
  }

  // =============================================
  // Aseguradoras
  // =============================================
  const fetchInsurers = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllInsurersAdmin()
      insurers.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar aseguradoras'
    } finally {
      loading.value = false
    }
  }

  const createInsurer = async (data) => {
    const result = await catalogsApi.createInsurer(data)
    if (result.success) insurers.value.push(result.data)
    return result
  }

  const updateInsurer = async (id, data) => {
    const result = await catalogsApi.updateInsurer(id, data)
    if (result.success) {
      const idx = insurers.value.findIndex(i => i.id_insurer === id)
      if (idx !== -1) insurers.value[idx] = result.data
    }
    return result
  }

  const toggleInsurer = async (id) => {
    const result = await catalogsApi.toggleInsurer(id)
    if (result.success) {
      const idx = insurers.value.findIndex(i => i.id_insurer === id)
      if (idx !== -1) insurers.value[idx] = result.data
    }
    return result
  }


  // =============================================
  // Tipos de Seguros
  // =============================================
  const insuranceTypes = ref([])
  const fetchInsuranceTypes = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllInsuranceTypesAdmin()
      insuranceTypes.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar seguros'
    } finally {
      loading.value = false
    }
  }

  const createInsuranceType = async (data) => {
    // Map to API names
    const payload = {
        code: data.code,
        name_insurance: data.name,
        descrip_insurance: data.description,
        is_mandatory: data.mandatory
    }
    const result = await catalogsApi.createInsuranceType(payload)
    if (result.success) insuranceTypes.value.push(result.data)
    return result
  }

  const updateInsuranceType = async (id, data) => {
    const payload = {
        code: data.code,
        name_insurance: data.name,
        descrip_insurance: data.description,
        is_mandatory: data.mandatory
    }
    const result = await catalogsApi.updateInsuranceType(id, payload)
    if (result.success) {
      const idx = insuranceTypes.value.findIndex(i => i.id_insurance_type === id)
      if (idx !== -1) insuranceTypes.value[idx] = result.data
    }
    return result
  }

  const toggleInsuranceType = async (id) => {
    const result = await catalogsApi.toggleInsuranceType(id)
    if (result.success) {
      const idx = insuranceTypes.value.findIndex(i => i.id_insurance_type === id)
      if (idx !== -1) insuranceTypes.value[idx] = result.data
    }
    return result
  }

  // =============================================
  // Tipos de Documentos de Transito
  // =============================================
  const transitDocs = ref([])
  const fetchTransitDocs = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllTransitDocsAdmin()
      transitDocs.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar documentos'
    } finally {
      loading.value = false
    }
  }

  const createTransitDoc = async (data) => {
    const payload = {
        code: data.code,
        name_doc: data.name,
        descrip_doc: data.description,
        is_mandatory: data.mandatory,
        has_expiration: data.expiration
    }
    const result = await catalogsApi.createTransitDoc(payload)
    if (result.success) transitDocs.value.push(result.data)
    return result
  }

  const updateTransitDoc = async (id, data) => {
    const payload = {
        code: data.code,
        name_doc: data.name,
        descrip_doc: data.description,
        is_mandatory: data.mandatory,
        has_expiration: data.expiration
    }
    const result = await catalogsApi.updateTransitDoc(id, payload)
    if (result.success) {
      const idx = transitDocs.value.findIndex(i => i.id_doc === id)
      if (idx !== -1) transitDocs.value[idx] = result.data
    }
    return result
  }

  const toggleTransitDoc = async (id) => {
    const result = await catalogsApi.toggleTransitDoc(id)
    if (result.success) {
      const idx = transitDocs.value.findIndex(i => i.id_doc === id)
      if (idx !== -1) transitDocs.value[idx] = result.data
    }
    return result
  }

  // =============================================
  // Tipos de Incidentes
  // =============================================
  const incidentTypes = ref([])
  const fetchIncidentTypes = async () => {
    loading.value = true
    error.value = null
    try {
      const result = await catalogsApi.getAllIncidentTypesAdmin()
      incidentTypes.value = result.data || []
    } catch (e) {
      error.value = e.response?.data?.message || 'Error al cargar incidentes'
    } finally {
      loading.value = false
    }
  }

  const createIncidentType = async (data) => {
    const payload = {
        tag_incident: data.code,
        name_incident: data.name
    }
    const result = await catalogsApi.createIncidentType(payload)
    if (result.success) incidentTypes.value.push(result.data)
    return result
  }

  const updateIncidentType = async (id, data) => {
    const payload = {
        tag_incident: data.code,
        name_incident: data.name
    }
    const result = await catalogsApi.updateIncidentType(id, payload)
    if (result.success) {
      const idx = incidentTypes.value.findIndex(i => i.id_incident === id)
      if (idx !== -1) incidentTypes.value[idx] = result.data
    }
    return result
  }

  const toggleIncidentType = async (id) => {
    const result = await catalogsApi.toggleIncidentType(id)
    if (result.success) {
      const idx = incidentTypes.value.findIndex(i => i.id_incident === id)
      if (idx !== -1) incidentTypes.value[idx] = result.data
    }
    return result
  }

  return {
    incidentTypes, fetchIncidentTypes, createIncidentType, updateIncidentType, toggleIncidentType,
    insuranceTypes, fetchInsuranceTypes, createInsuranceType, updateInsuranceType, toggleInsuranceType, transitDocs, fetchTransitDocs, createTransitDoc, updateTransitDoc, toggleTransitDoc,
    eps, arl, brands, companies, insurers, loading, error,
    fetchEps, createEps, updateEps, toggleEps,
    fetchArl, createArl, updateArl, toggleArl,
    fetchBrands, createBrand, updateBrand, toggleBrand,
    fetchCompanies, createCompany, updateCompany, toggleCompany,
    fetchInsurers, createInsurer, updateInsurer, toggleInsurer,
  }
})
