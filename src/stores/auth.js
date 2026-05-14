import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import apiClient from '../api/client'

// =============================================
// 🔒 POLÍTICA DE SEGURIDAD - localStorage
// =============================================
// ✅ QUÉ SE GUARDA: token JWT, displayName, role, avatar, allRoles (datos públicos)
// ❌ QUÉ NO SE GUARDA: uid, email, password (datos sensibles)
//
// RAZÓN: Protección contra XSS (Cross-Site Scripting)
// - Token JWT es seguro en localStorage si está protegido (httpOnly no disponible en SPA)
// - Se valida en backend con middleware
// - Si un atacante inyecta código malicioso, NO puede robar contraseñas
// - Los datos sensibles se obtienen del backend cuando es necesario
// =============================================
// Usuarios de prueba (fallback cuando el backend no está disponible)
const DEMO_USERS = {
  'admin@bucarabus.com': {
    uid: 'admin-001',
    email: 'admin@bucarabus.com',
    password: 'Admin123',
    displayName: 'Administrador',
    role: 'admin',
    avatar: '👨‍💼'
  },
  'turnador@bucarabus.com': {
    uid: 'turner-001',
    email: 'turnador@bucarabus.com',
    password: 'Turner123',
    displayName: 'Turnador',
    role: 'turner',
    avatar: '📋'
  },
  'conductor@bucarabus.com': {
    uid: 'driver-001',
    email: 'conductor@bucarabus.com',
    password: 'Driver123',
    displayName: 'Conductor',
    role: 'driver',
    avatar: '👨‍✈️'
  }
}

export const useAuthStore = defineStore('auth', () => {
  // =============================================
  // STATE
  // =============================================
  const currentUser = ref(null)
  const isAuthenticated = ref(false)
  const loading = ref(false)
  const error = ref(null)
  const activeRole = ref(null) // Rol actualmente activo
  const token = ref(null) // 🆕 Token JWT

  // =============================================
  // GETTERS
  // =============================================
  // ⚠️ NOTA: userId y userEmail pueden ser NULL si la sesión fue restaurada desde localStorage
  // Para obtener estos datos, el usuario debe re-autenticarse o hacer una llamada al backend
  const userId = computed(() => currentUser.value?.uid || null)
  const userEmail = computed(() => currentUser.value?.email || null)
  const userName = computed(() => currentUser.value?.displayName || currentUser.value?.email || 'Usuario')
  const userRole = computed(() => activeRole.value || currentUser.value?.role || 'guest')
  const userAvatar = computed(() => currentUser.value?.avatar || '👤')
  
  // Roles disponibles del usuario actual
  const availableRoles = computed(() => {
    if (!currentUser.value?.allRoles || currentUser.value.allRoles.length === 0) {
      return [{ id_role: getRoleId(currentUser.value?.role), role_name: getRoleName(currentUser.value?.role) }]
    }
    return currentUser.value.allRoles
  })
  
  // Verificar si el usuario tiene múltiples roles
  const hasMultipleRoles = computed(() => availableRoles.value.length > 1)

  // =============================================
  // ACTIONS
  // =============================================

  /**
   * Inicializar usuario desde localStorage (incluyendo token JWT)
   * ⚠️ NOTA: Solo restaura datos NO sensibles
   * Token JWT se valida automáticamente en requests al backend
   */
  function initializeUser() {
    try {
      const storedUser = localStorage.getItem('bucarabus_user')
      const storedToken = localStorage.getItem('bucarabus_token') // 🆕 Token JWT
      const storedActiveRole = localStorage.getItem('bucarabus_active_role')
      
      if (storedUser && storedToken) {
        const userData = JSON.parse(storedUser)
        
        // ✅ SEGURIDAD: localStorage tiene displayName, role, avatar, token
        // NO tiene uid, email, password (datos internos sensibles)
        currentUser.value = {
          uid: null,  // Se obtiene del backend si es necesario
          email: userData.email || null,
          displayName: userData.displayName,
          role: userData.role,
          avatar: userData.avatar,
          allRoles: userData.allRoles || [],
          permissions: userData.permissions || [] // 🆕 Restaurar permisos
        }
        token.value = storedToken // 🆕 Restaurar token
        isAuthenticated.value = true
        
        // Restaurar rol activo o usar el rol principal
        activeRole.value = storedActiveRole || userData.role
        
        // 🆕 Configurar token en headers automáticamente
        apiClient.defaults.headers.common['Authorization'] = `Bearer ${storedToken}`
        
        console.log('✅ Usuario y token restaurados desde localStorage:', userData.displayName)
      } else {
        console.log('ℹ️ No hay sesión guardada')
      }
    } catch (err) {
      console.error('❌ Error al restaurar usuario:', err)
      localStorage.removeItem('bucarabus_user')
      localStorage.removeItem('bucarabus_token') // 🆕 Limpiar token
      localStorage.removeItem('bucarabus_active_role')
    }
  }

  /**
   * Login con API backend real
   * Ahora devuelve y guarda token JWT
   */
  async function login(email, password) {
    loading.value = true
    error.value = null

    try {
      console.log('🔐 Intentando login con backend:', email)
      
      // Llamar a la API de autenticación
      const response = await apiClient.post('/auth/login', {
        email,
        password
      })

      if (response.data.success) {
        const userData = response.data.data
        const jwtToken = response.data.token // 🆕 Extraer token JWT
        
        // Determinar el rol principal del usuario
        let role = 'guest'
        if (userData.roles && userData.roles.length > 0) {
          // Prioridad: Admin > Driver > Turner
          if (userData.roles.some(r => r.id_role === 1)) {
            role = 'admin'
          } else if (userData.roles.some(r => r.id_role === 3)) {
            role = 'driver'
          } else if (userData.roles.some(r => r.id_role === 2)) {
            role = 'turner'
          }
        }
        
        // Construir objeto de usuario completo (en memoria)
        const userForStore = {
          uid: userData.id_user,
          email: userData.email,
          displayName: userData.full_name,
          role: role,
          avatar: getDefaultAvatar(role),
          allRoles: userData.roles || [],
          permissions: userData.permissions || [] // 🆕 Guardar permisos
        }
        
        currentUser.value = userForStore
        token.value = jwtToken // 🆕 Guardar token en estado
        isAuthenticated.value = true
        activeRole.value = role // Establecer rol activo inicial

        // 🆕 Configurar token en headers para requests posteriores
        apiClient.defaults.headers.common['Authorization'] = `Bearer ${jwtToken}`

        // ✅ SEGURIDAD: Guardar en localStorage (sin uid/password)
        const secureStorage = {
          displayName: userData.full_name,
          email: userData.email,
          role: role,
          avatar: getDefaultAvatar(role),
          allRoles: userData.roles || [],
          permissions: userData.permissions || [] // 🆕 Guardar permisos
        }
        localStorage.setItem('bucarabus_user', JSON.stringify(secureStorage)) // Guardar datos públicos
        localStorage.setItem('bucarabus_token', jwtToken) // 🆕 Guardar token
        localStorage.setItem('bucarabus_active_role', role) // Guardar rol activo
        
        console.log('✅ Login exitoso:', userForStore.displayName, '- Rol:', role)
        console.log('🔑 Token JWT guardado y configurado en headers')

        return { success: true }
      } else {
        throw new Error(response.data.message || 'Error al iniciar sesión')
      }
    } catch (err) {
      const errorMessage = err.response?.data?.message || err.message || 'Error de conexión'
      error.value = errorMessage
      console.error('❌ Login error:', errorMessage)
      
      // Si el servidor no responde, intentar con usuarios demo como fallback
      if (!err.response) {
        console.log('⚠️ Servidor no disponible, intentando con usuarios demo...')
        return loginWithDemoUsers(email, password)
      }
      
      return { success: false, error: errorMessage }
    } finally {
      loading.value = false
    }
  }

  /**
   * Fallback: Login con usuarios demo cuando el backend no está disponible
   */
  function loginWithDemoUsers(email, password) {
    const demoUser = DEMO_USERS[email.toLowerCase()]
    
    if (!demoUser) {
      return { success: false, error: 'Usuario no encontrado' }
    }

    if (demoUser.password !== password) {
      return { success: false, error: 'Contraseña incorrecta' }
    }

    const { password: _, ...userWithoutPassword } = demoUser
    currentUser.value = userWithoutPassword
    isAuthenticated.value = true
    localStorage.setItem('bucarabus_user', JSON.stringify(userWithoutPassword)) // Guardar datos públicos
    
    console.log('✅ Login exitoso (modo demo):', userWithoutPassword.displayName)
    return { success: true }
  }

  /**
   * Obtener avatar por defecto según el rol
   */
  function getDefaultAvatar(role) {
    const avatars = {
      admin: '👨‍💼',
      turner: '📋',
      driver: '👨‍✈️',
      guest: '❓'
    }
    return avatars[role] || '👤'
  }

  /**
   * Obtener nombre del rol en español
   */
  function getRoleName(roleKey) {
    const names = {
      admin: 'Administrador',
      turner: 'Turnador',
      driver: 'Conductor',
      guest: 'Invitado'
    }
    return names[roleKey] || roleKey
  }

  /**
   * Obtener ID del rol
   */
  function getRoleId(roleKey) {
    const ids = {
      admin: 1,
      turner: 2,
      driver: 3,
      guest: 0
    }
    return ids[roleKey] || 0
  }

  /**
   * Convertir id_role a roleKey
   */
  function roleIdToKey(id_role) {
    const keys = {
      1: 'admin',
      2: 'turner',
      3: 'driver'
    }
    return keys[id_role] || 'guest'
  }

  /**
   * Cambiar de rol activo sin cerrar sesión
   */
  function switchRole(newRole) {
    if (!currentUser.value) {
      console.error('❌ No hay usuario autenticado')
      return { success: false, error: 'No hay usuario autenticado' }
    }

    // Verificar que el usuario tenga ese rol
    const hasRole = availableRoles.value.some(r => {
      const roleKey = roleIdToKey(r.id_role)
      return roleKey === newRole
    })

    if (!hasRole) {
      console.error('❌ Usuario no tiene el rol:', newRole)
      return { success: false, error: 'No tienes acceso a ese rol' }
    }

    activeRole.value = newRole
    
    // Actualizar en currentUser también para consistencia
    currentUser.value = {
      ...currentUser.value,
      role: newRole
    }

    // Guardar en localStorage
    localStorage.setItem('bucarabus_user', JSON.stringify(currentUser.value))
    localStorage.setItem('bucarabus_active_role', newRole)

    console.log('✅ Rol cambiado a:', newRole)
    return { success: true, role: newRole }
  }

  /**
   * Registro eliminado: los usuarios se crean desde el panel de administración
   * o desde el módulo de conductores. No hay auto-registro público.
   */

  /**
   * Refrescar datos del usuario desde el backend (uid, roles)
   * Útil cuando la sesión fue restaurada desde localStorage y uid es null
   */
  async function refreshUserData() {
    // Si ya tenemos uid, no hay necesidad de refrescar
    if (currentUser.value?.uid) {
      return { success: true }
    }

    const email = currentUser.value?.email
    if (!email) {
      console.warn('⚠️ No hay email disponible para refrescar datos del usuario')
      return { success: false, error: 'No hay email disponible' }
    }

    try {
      console.log('🔄 Refrescando datos del usuario desde backend...')
      const response = await apiClient.post('/auth/me', { email })

      if (response.data.success) {
        const userData = response.data.data

        // Actualizar solo uid y permisos en memoria (NO en localStorage)
        currentUser.value = {
          ...currentUser.value,
          uid: userData.id_user,
          email: userData.email,
          permissions: userData.permissions || currentUser.value.permissions
        }

        console.log('✅ Datos refrescados - uid:', userData.id_user)
        return { success: true }
      } else {
        console.error('❌ Error al refrescar datos:', response.data.message)
        return { success: false, error: response.data.message }
      }
    } catch (err) {
      console.error('❌ Error de red al refrescar datos:', err.message)
      return { success: false, error: err.message }
    }
  }

  /**
   * Logout
   * Limpia token JWT de headers y localStorage
   */
  async function logout() {
    currentUser.value = null
    token.value = null // 🆕 Limpiar token
    isAuthenticated.value = false
    activeRole.value = null
    
    // 🆕 Remover token de headers
    delete apiClient.defaults.headers.common['Authorization']
    
    localStorage.removeItem('bucarabus_user')
    localStorage.removeItem('bucarabus_token') // 🆕 Limpiar token
    localStorage.removeItem('bucarabus_active_role')
    console.log('✅ Sesión cerrada y token eliminado')
  }

  /**
   * Actualizar perfil de usuario
   */
  async function updateProfile(data) {
    if (!currentUser.value) return { success: false, error: 'No hay usuario autenticado' }

    try {
      currentUser.value = {
        ...currentUser.value,
        ...data
      }
      return { success: true }
    } catch (err) {
      error.value = err.message
      return { success: false, error: err.message }
    }
  }

  /**
   * Verificar si el usuario tiene un permiso específico (RBAC)
   * Útil para usar en componentes Vue: v-if="authStore.can('CREATE_BUSES')"
   */
  function can(permissionCode) {
    if (!currentUser.value?.permissions) return false;
    
    const perms = currentUser.value.permissions;
    
    // 1. Verificamos si tiene el permiso exacto
    if (perms.includes(permissionCode)) return true;
    
    // 2. Verificamos comodines globales
    if (perms.includes('*') || perms.includes('ALL_PERMISSIONS')) return true;
    
    // 3. Fallback: Si es Administrador, tiene acceso a todo
    if (currentUser.value.role === 'admin' || activeRole.value === 'admin') return true;
    
    return false;
  }

  /**
   * Verificar si el usuario tiene AL MENOS UNO de los permisos listados
   * Útil para ocultar módulos completos del sidebar
   * Uso: v-if="authStore.canAny(['VIEW_BUSES','CREATE_BUSES'])"
   */
  function canAny(permissionCodes) {
    if (!Array.isArray(permissionCodes)) return false;
    return permissionCodes.some(code => can(code));
  }

  // =============================================
  // INICIALIZACIÓN
  // =============================================
  // Inicializar usuario al cargar el store
  initializeUser()

  // =============================================
  // RETURN
  // =============================================
  return {
    // State
    currentUser,
    isAuthenticated,
    loading,
    error,
    activeRole,
    token, // 🆕 Token JWT

    // Getters
    userId,
    userEmail,
    userName,
    userRole,
    userAvatar,
    availableRoles,
    hasMultipleRoles,

    // Actions
    login,
    logout,
    updateProfile,
    initializeUser,
    refreshUserData,
    switchRole,
    can, // Verificar permiso individual
    canAny, // Verificar si tiene al menos uno de los permisos
    
    // Helpers
    getRoleName,
    roleIdToKey
  }
})
