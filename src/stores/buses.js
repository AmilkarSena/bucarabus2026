import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as busesApi from '../api/buses.js'
import { SYSTEM_USER_ID } from '../constants/system'

export const useBusesStore = defineStore('buses', () => {
  // Estado
  const buses = ref([])
  const loading = ref(false)
  const error = ref(null)

  // Getters computados
  const activeBuses = computed(() => 
    buses.value.filter(bus => bus.is_active)
  )
  
  const availableBuses = computed(() => 
    buses.value.filter(bus => bus.is_active && !bus.assigned_driver)
  )
  
  const inactiveBuses = computed(() => 
    buses.value.filter(bus => !bus.is_active)
  )
  
  const totalCapacity = computed(() => 
    buses.value
      .filter(bus => bus.is_active)
      .reduce((sum, bus) => sum + (bus.capacity_bus || 0), 0)
  )

  const expiringSoon = computed(() =>
    buses.value.filter(bus => {
      if (!bus.is_active) return false
      const items = [...(bus.insurance_coverage || []), ...(bus.transit_doc_coverage || [])]
      return items.some(a => a.status === 'expiring' || a.status === 'expired' || a.status === 'missing')
    })
  )

  // Acciones

  /**
   * Cargar todos los buses desde la API
   */
  const fetchBuses = async (onlyActive = false) => {
    loading.value = true
    error.value = null

    try {
      const result = await busesApi.getAllBuses(onlyActive)
      
      if (result.success) {
        buses.value = result.data
        console.log('✅ Buses cargados:', buses.value.length)
        return { success: true, data: buses.value }
      } else {
        throw new Error(result.message || 'Error al cargar buses')
      }
    } catch (err) {
      console.error('❌ Error al cargar buses:', err)
      error.value = err.message
      return { success: false, error: err.message }
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear nuevo bus
   */
  const createBus = async (busData) => {
    loading.value = true
    error.value = null

    try {
      const result = await busesApi.createBus(busData)
      
      if (result.success) {
        // Agregar el nuevo bus al store
        buses.value.push(result.data)
        console.log('✅ Bus creado:', result.data)
        return { success: true, data: result.data, message: result.message }
      } else {
        throw new Error(result.message || 'Error al crear bus')
      }
    } catch (err) {
      console.error('❌ Error al crear bus:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message,
        error_code: err.response?.data?.error_code
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Actualizar bus existente
   */
  const updateBus = async (plateNumber, busData) => {
    loading.value = true
    error.value = null

    try {
      const result = await busesApi.updateBus(plateNumber, busData)
      
      if (result.success) {
        // Actualizar el bus en el store
        const index = buses.value.findIndex(b => b.plate_number === plateNumber)
        if (index !== -1) {
          buses.value[index] = result.data
        }
        console.log('✅ Bus actualizado:', result.data)
        return { success: true, data: result.data, message: result.message }
      } else {
        throw new Error(result.message || 'Error al actualizar bus')
      }
    } catch (err) {
      console.error('❌ Error al actualizar bus:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message,
        error_code: err.response?.data?.error_code
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Eliminar bus (soft delete)
   */
  const deleteBus = async (plateNumber, userUpdate = SYSTEM_USER_ID) => {
    loading.value = true
    error.value = null

    try {
      const result = await busesApi.deleteBus(plateNumber, userUpdate)
      
      if (result.success) {
        // Actualizar el estado del bus en el store
        const bus = buses.value.find(b => b.plate_number === plateNumber)
        if (bus) {
          bus.is_active = false
        }
        console.log('✅ Bus eliminado (soft delete):', plateNumber)
        return { success: true, message: result.message }
      } else {
        throw new Error(result.message || 'Error al eliminar bus')
      }
    } catch (err) {
      console.error('❌ Error al eliminar bus:', err)
      error.value = err.response?.data?.message || err.message
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    } finally {
      loading.value = false
    }
  }

  /**
   * Cambiar estado del bus (activar/desactivar)
   */
  const toggleBusStatus = async (plateNumber, isActive, userUpdate = SYSTEM_USER_ID) => {
    try {
      const result = await busesApi.toggleBusStatus(plateNumber, isActive, userUpdate)
      
      if (result.success) {
        // Actualizar el estado en el store
        const bus = buses.value.find(b => b.plate_number === plateNumber)
        if (bus) {
          bus.is_active = isActive
          bus.updated_at = new Date().toISOString()
        }
        console.log(`✅ Estado cambiado: ${plateNumber} → ${isActive ? 'activo' : 'inactivo'}`)
        return { success: true, data: result.data, message: result.message }
      } else {
        throw new Error(result.message || 'Error al cambiar estado')
      }
    } catch (err) {
      console.error('❌ Error al cambiar estado del bus:', err)
      return { 
        success: false, 
        error: err.response?.data?.message || err.message 
      }
    }
  }

  /**
   * Obtener bus por placa
   */
  const getBusByPlate = (plateNumber) => {
    return buses.value.find(b => b.plate_number === plateNumber)
  }

  /**
   * Obtener estadísticas de buses
   */
  const fetchStats = async () => {
    try {
      const result = await busesApi.getBusStats()
      if (result.success) {
        return { success: true, data: result.data }
      }
      throw new Error(result.message)
    } catch (err) {
      console.error('❌ Error al obtener estadísticas:', err)
      return { success: false, error: err.message }
    }
  }

  return {
    // Estado
    buses,
    loading,
    error,
    
    // Getters
    activeBuses,
    availableBuses,
    inactiveBuses,
    totalCapacity,
    expiringSoon,
    
    // Acciones
    fetchBuses,
    createBus,
    updateBus,
    deleteBus,
    toggleBusStatus,
    getBusByPlate,
    fetchStats
  }
})
