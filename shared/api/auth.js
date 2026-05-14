import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from './client'

// Utilidades fuera del store para evitar problemas de hoisting/scope
export const getDefaultAvatar = (role) => ({ admin: '👨‍💼', turner: '📋', driver: '👨‍✈️', guest: '❓' })[role] || '👤'
export const getRoleName = (roleKey) => ({ admin: 'Administrador', turner: 'Turnador', driver: 'Conductor', guest: 'Invitado' })[roleKey] || roleKey
export const getRoleId = (roleKey) => ({ admin: 1, turner: 2, driver: 3, guest: 0 })[roleKey] || 0
export const roleIdToKey = (id_role) => ({ 1: 'admin', 2: 'turner', 3: 'driver' })[id_role] || 'guest'

export const useAuthStore = defineStore('auth', () => {
  const currentUser     = ref(null)
  const isAuthenticated = ref(false)
  const loading         = ref(false)
  const error           = ref(null)
  const activeRole      = ref(null)
  const token           = ref(null)

  const userId          = computed(() => currentUser.value?.uid    || null)
  const userEmail       = computed(() => currentUser.value?.email  || null)
  const userName        = computed(() => currentUser.value?.displayName || currentUser.value?.email || 'Usuario')
  const userRole        = computed(() => activeRole.value || currentUser.value?.role || 'guest')
  const userAvatar      = computed(() => currentUser.value?.avatar || '👤')
  
  const availableRoles  = computed(() => {
    const baseRoles = currentUser.value?.allRoles || []
    if (baseRoles.length === 0 && currentUser.value?.role) {
      return [{ id_role: getRoleId(currentUser.value.role), role_name: getRoleName(currentUser.value.role) }]
    }
    return baseRoles
  })
  
  const hasMultipleRoles = computed(() => availableRoles.value.length > 1)

  function initializeUser() {
    console.log('🔄 Inicializando usuario desde localStorage...')
    try {
      const storedUser   = localStorage.getItem('bucarabus_user')
      const storedToken  = localStorage.getItem('bucarabus_token')
      const storedRole   = localStorage.getItem('bucarabus_active_role')
      
      if (storedUser && storedToken) {
        const userData = JSON.parse(storedUser)
        currentUser.value = { 
          uid: userData.uid || null, 
          email: userData.email || null, 
          displayName: userData.displayName, 
          role: userData.role, 
          avatar: userData.avatar, 
          allRoles: userData.allRoles || [], 
          permissions: userData.permissions || [] 
        }
        token.value           = storedToken
        isAuthenticated.value = true
        activeRole.value      = storedRole || userData.role
        apiClient.defaults.headers.common['Authorization'] = `Bearer ${storedToken}`
        console.log('✅ Usuario cargado:', currentUser.value.email)
      }
    } catch (err) {
      console.error('❌ Error en initializeUser:', err)
      logout()
    }
  }

  async function login(email, password) {
    loading.value = true
    error.value   = null
    try {
      const response = await apiClient.post('/auth/login', { email, password })
      if (response.data.success) {
        const userData = response.data.data
        const jwtToken = response.data.token
        
        let role = 'guest'
        if (userData.roles?.length) {
          if      (userData.roles.some(r => r.id_role === 1)) role = 'admin'
          else if (userData.roles.some(r => r.id_role === 3)) role = 'driver'
          else if (userData.roles.some(r => r.id_role === 2)) role = 'turner'
        }
        
        const userForStore = { 
          uid: userData.id_user, 
          email: userData.email, 
          displayName: userData.full_name, 
          role, 
          avatar: getDefaultAvatar(role), 
          allRoles: userData.roles || [], 
          permissions: userData.permissions || [] 
        }
        
        currentUser.value     = userForStore
        token.value           = jwtToken
        isAuthenticated.value = true
        activeRole.value      = role
        apiClient.defaults.headers.common['Authorization'] = `Bearer ${jwtToken}`
        
        localStorage.setItem('bucarabus_user', JSON.stringify(userForStore))
        localStorage.setItem('bucarabus_token', jwtToken)
        localStorage.setItem('bucarabus_active_role', role)
        
        return { success: true }
      } else { 
        throw new Error(response.data.message || 'Error al iniciar sesión') 
      }
    } catch (err) {
      const errorMessage = err.response?.data?.message || err.message || 'Error de conexión'
      error.value = errorMessage
      return { success: false, error: errorMessage }
    } finally { 
      loading.value = false 
    }
  }

  function switchRole(newRole) {
    if (!currentUser.value) return { success: false, error: 'No hay usuario autenticado' }
    const hasRole = availableRoles.value.some(r => roleIdToKey(r.id_role) === newRole)
    if (!hasRole) return { success: false, error: 'No tienes acceso a ese rol' }
    
    activeRole.value = newRole
    currentUser.value = { ...currentUser.value, role: newRole }
    localStorage.setItem('bucarabus_user', JSON.stringify(currentUser.value))
    localStorage.setItem('bucarabus_active_role', newRole)
    return { success: true, role: newRole }
  }

  async function refreshUserData() {
    if (!currentUser.value?.email) return { success: false, error: 'No hay email disponible' }
    try {
      const response = await apiClient.post('/auth/me', { email: currentUser.value.email })
      if (response.data.success) {
        currentUser.value = { 
          ...currentUser.value, 
          uid: response.data.data.id_user, 
          permissions: response.data.data.permissions || currentUser.value.permissions 
        }
        return { success: true }
      }
      return { success: false, error: response.data.message }
    } catch (err) { 
      return { success: false, error: err.message } 
    }
  }

  function logout() {
    currentUser.value = null
    token.value = null
    isAuthenticated.value = false
    activeRole.value = null
    delete apiClient.defaults.headers.common['Authorization']
    localStorage.removeItem('bucarabus_user')
    localStorage.removeItem('bucarabus_token')
    localStorage.removeItem('bucarabus_active_role')
  }

  async function updateProfile(data) {
    if (!currentUser.value) return { success: false, error: 'No hay usuario autenticado' }
    currentUser.value = { ...currentUser.value, ...data }
    localStorage.setItem('bucarabus_user', JSON.stringify(currentUser.value))
    return { success: true }
  }

  function can(permissionCode) {
    if (!currentUser.value?.permissions) return false
    const perms = currentUser.value.permissions
    if (perms.includes(permissionCode) || perms.includes('*') || perms.includes('ALL_PERMISSIONS')) return true
    return userRole.value === 'admin'
  }

  function canAny(permissionCodes) { 
    return Array.isArray(permissionCodes) && permissionCodes.some(c => can(c)) 
  }

  initializeUser()

  return {
    currentUser, isAuthenticated, loading, error, activeRole, token,
    userId, userEmail, userName, userRole, userAvatar, availableRoles, hasMultipleRoles,
    login, logout, updateProfile, initializeUser, refreshUserData, switchRole,
    can, canAny, getRoleName, roleIdToKey
  }
})
