/**
 * Composable que actúa como un "Middleware de Seguridad" para rutas y componentes protegidos.
 * 
 * Este módulo verifica que el usuario no solo esté autenticado técnicamente (token), 
 * sino que posea una "Sesión Completa":
 * 1. Validación de Identidad: Comprueba que el `userId` y `email` estén presentes en el Store.
 * 2. Prevención de Sesiones Huérfanas: Identifica casos donde existen datos en localStorage 
 *    pero falta la vinculación con el backend, forzando un re-login seguro.
 * 3. Redirección Inteligente: Redirige automáticamente al login capturando la ruta de origen 
 *    (`returnPath`) para permitir un retorno fluido tras la autenticación.
 * 4. Control de Acceso: Provee estados reactivos para ocultar/mostrar elementos UI según el 
 *    nivel de acceso del usuario.
 */

import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

export function useRequireFullSession() {
  const authStore = useAuthStore()
  const router = useRouter()

  // Verificar si tiene sesión completa (uid y email disponibles)
  const hasFullSession = computed(() => {
    return authStore.isAuthenticated && authStore.userId !== null
  })

  /**
   * Requiere sesión completa, redirige a login si solo tiene datos de localStorage
   * @param {string} returnPath - Ruta a la que volver después del login
   */
  function requireFullSession(returnPath = null) {
    if (!authStore.isAuthenticated) {
      console.warn('⚠️ No hay sesión activa, redirigiendo a login...')
      router.push({
        path: '/login',
        query: returnPath ? { redirect: returnPath } : {}
      })
      return false
    }

    if (authStore.userId === null) {
      console.warn('⚠️ Sesión limitada (solo localStorage), requiere re-login para obtener uid/email')
      router.push({
        path: '/login',
        query: { 
          redirect: returnPath || router.currentRoute.value.fullPath,
          reason: 'session_limited'
        }
      })
      return false
    }

    return true
  }

  return {
    hasFullSession,
    requireFullSession
  }
}
