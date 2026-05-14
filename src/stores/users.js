import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from '../api/client'

export const useUsersStore = defineStore('users', () => {
  // =============================================
  // STATE
  // =============================================
  const users = ref([])
  const loading = ref(false)
  const error = ref(null)
  const currentUser = ref(null)

  // =============================================
  // GETTERS (COMPUTED)
  // =============================================
  const totalUsers = computed(() => users.value.length)

  const activeUsers = computed(() => 
    users.value.filter(user => user.is_active)
  )

  const inactiveUsers = computed(() => 
    users.value.filter(user => !user.is_active)
  )

  const usersByRole = computed(() => {
    return {
      passengers: users.value.filter(u => u.roles?.some(r => r.id_role === 1)).length,
      drivers: users.value.filter(u => u.roles?.some(r => r.id_role === 2)).length,
      supervisors: users.value.filter(u => u.roles?.some(r => r.id_role === 3)).length,
      admins: users.value.filter(u => u.roles?.some(r => r.id_role === 4)).length
    }
  })

  const getUsersByRoleId = computed(() => {
    return (roleId) => users.value.filter(u => 
      u.roles?.some(r => r.id_role === roleId)
    )
  })

  // =============================================
  // ACTIONS
  // =============================================

  /**
   * Obtener todos los usuarios
   * @param {Object} params - Parámetros de filtrado
   * @param {string} params.role - Filtrar por rol (1=Pasajero, 2=Conductor, 3=Supervisor, 4=Admin)
   * @param {boolean} params.active - Filtrar por estado activo
   */
  async function fetchUsers(params = {}) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Obteniendo usuarios...', params)
      const response = await apiClient.get('/users', { params })
      
      const usersData = response.data.data || response.data
      
      if (Array.isArray(usersData)) {
        users.value = usersData
        console.log(`✅ ${usersData.length} usuarios cargados`)
      } else {
        throw new Error('Formato de respuesta inválido')
      }
    } catch (err) {
      console.error('❌ Error cargando usuarios:', err)
      error.value = err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Obtener usuario por ID
   * @param {number} userId - ID del usuario
   */
  async function fetchUserById(userId) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Obteniendo usuario:', userId)
      const response = await apiClient.get(`/users/${userId}`)
      
      const userData = response.data.data || response.data
      currentUser.value = userData
      
      console.log('✅ Usuario cargado:', userData.full_name)
      return userData
    } catch (err) {
      console.error('❌ Error cargando usuario:', err)
      error.value = err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Crear nuevo usuario
   * @param {Object} userData - Datos del usuario
   * @param {string} userData.email - Email del usuario
   * @param {string} userData.password - Contraseña (se hasheará en el backend)
   * @param {string} userData.full_name - Nombre completo
   * @param {string} userData.avatar_url - URL del avatar (opcional)
   * @param {number} userData.initial_role - Rol inicial (1=Pasajero por defecto)
   */
  async function createUser(userData) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Creando usuario:', userData.email)
      console.log('📦 Datos completos:', JSON.stringify(userData, null, 2))
      console.log('🌐 URL base de apiClient:', apiClient.defaults.baseURL)
      const response = await apiClient.post('/users', userData)
      
      const newUser = response.data.data || response.data
      
      // Agregar a la lista local
      users.value.push(newUser)
      
      console.log('✅ Usuario creado:', newUser.id_user)
      return newUser
    } catch (err) {
      console.error('❌ Error creando usuario:', err)
      error.value = err.response?.data?.message || err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Actualizar usuario (nombre y avatar)
   * @param {number} userId - ID del usuario
   * @param {Object} updates - Campos a actualizar
   * @param {string} updates.full_name - Nuevo nombre (opcional)
   * @param {string} updates.avatar_url - Nueva URL avatar (opcional)
   */
  async function updateUser(userId, updates) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Actualizando usuario:', userId)
      const response = await apiClient.put(`/users/${userId}`, updates)
      
      const updatedUser = response.data.data || response.data
      
      // Actualizar en la lista local
      const index = users.value.findIndex(u => u.id_user === userId)
      if (index !== -1) {
        users.value[index] = { ...users.value[index], ...updatedUser }
      }
      
      console.log('✅ Usuario actualizado:', updatedUser.full_name)
      return updatedUser
    } catch (err) {
      console.error('❌ Error actualizando usuario:', err)
      error.value = err.response?.data?.message || err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Cambiar contraseña de usuario
   * @param {number} userId - ID del usuario
   * @param {string} newPassword - Nueva contraseña
   */
  async function changePassword(userId, newPassword) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Cambiando contraseña usuario:', userId)
      const response = await apiClient.put(`/users/${userId}/password`, { 
        newPassword: newPassword 
      })
      
      console.log('✅ Contraseña actualizada')
      return response.data
    } catch (err) {
      console.error('❌ Error cambiando contraseña:', err)
      error.value = err.response?.data?.message || err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Activar/Desactivar usuario
   * @param {number} userId - ID del usuario
   * @param {boolean} isActive - Estado activo (true/false)
   */
  async function toggleUserStatus(userId, isActive) {
    loading.value = true
    error.value = null

    try {
      console.log(`🔄 ${isActive ? 'Activando' : 'Desactivando'} usuario:`, userId)
      const response = await apiClient.put(`/users/${userId}/status`, { 
        isActive: isActive 
      })
      
      // Actualizar en la lista local
      const index = users.value.findIndex(u => u.id_user === userId)
      if (index !== -1) {
        users.value[index].is_active = isActive
      }
      
      console.log('✅ Estado actualizado')
      return response.data
    } catch (err) {
      console.error('❌ Error cambiando estado:', err)
      error.value = err.response?.data?.message || err.message
      throw err  
    } finally {
      loading.value = false
    }
  }

  /**
   * Obtener roles de un usuario
   * @param {number} userId - ID del usuario
   */
  async function getUserRoles(userId) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Obteniendo roles de usuario:', userId)
      const response = await apiClient.get(`/users/${userId}/roles`)
      
      const roles = response.data.data || response.data
      
      console.log('✅ Roles obtenidos:', roles.length)
      return roles
    } catch (err) {
      console.error('❌ Error obteniendo roles:', err)
      error.value = err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Asignar rol a usuario
   * @param {number} userId - ID del usuario
   * @param {number} roleId - ID del rol (1=Pasajero, 2=Conductor, 3=Supervisor, 4=Admin)
   */
  async function assignRole(userId, roleId) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Asignando rol', roleId, 'a usuario', userId)
      const response = await apiClient.post(`/users/${userId}/roles`, { 
        roleId: roleId  // ✅ Corregido: usar "roleId" como espera el backend
      })
      
      // Actualizar usuario en la lista local
      await fetchUserById(userId)
      const updatedUser = currentUser.value
      const index = users.value.findIndex(u => u.id_user === userId)
      if (index !== -1) {
        users.value[index] = updatedUser
      }
      
      console.log('✅ Rol asignado')
      return response.data
    } catch (err) {
      console.error('❌ Error asignando rol:', err)
      error.value = err.response?.data?.message || err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Quitar rol de usuario
   * @param {number} userId - ID del usuario
   * @param {number} roleId - ID del rol a quitar
   */
  async function removeRole(userId, roleId) {
    loading.value = true
    error.value = null

    try {
      console.log('🔄 Quitando rol', roleId, 'de usuario', userId)
      const response = await apiClient.delete(`/users/${userId}/roles/${roleId}`)
      
      // Actualizar usuario en la lista local
      await fetchUserById(userId)
      const updatedUser = currentUser.value
      const index = users.value.findIndex(u => u.id_user === userId)
      if (index !== -1) {
        users.value[index] = updatedUser
      }
      
      console.log('✅ Rol quitado')
      return response.data
    } catch (err) {
      console.error('❌ Error quitando rol:', err)
      error.value = err.response?.data?.message || err.message
      throw err
    } finally {
      loading.value = false
    }
  }

  /**
   * Buscar usuarios
   * @param {string} query - Texto a buscar (nombre o email)
   */
  function searchUsers(query) {
    if (!query) return users.value
    
    const lowerQuery = query.toLowerCase()
    return users.value.filter(user => 
      user.full_name?.toLowerCase().includes(lowerQuery) ||
      user.email?.toLowerCase().includes(lowerQuery)
    )
  }

  /**
   * Limpiar estado
   */
  function clearUsers() {
    users.value = []
    currentUser.value = null
    error.value = null
  }

  return {
    // State
    users,
    loading,
    error,
    currentUser,

    // Getters
    totalUsers,
    activeUsers,
    inactiveUsers,
    usersByRole,
    getUsersByRoleId,

    // Actions
    fetchUsers,
    fetchUserById,
    createUser,
    updateUser,
    changePassword,
    toggleUserStatus,
    getUserRoles,
    assignRole,
    removeRole,
    searchUsers,
    clearUsers
  }
})
