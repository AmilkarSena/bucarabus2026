import axios from 'axios'

// Detectar URL del API según el host actual
// Esto permite acceder desde celular en la misma red sin cambiar .env
const getApiBaseUrl = () => {
  if (import.meta.env.VITE_API_URL) return import.meta.env.VITE_API_URL
  const hostname = window.location.hostname
  if (hostname === 'localhost' || hostname === '127.0.0.1') return 'http://localhost:3001/api'
  // Mismo host que el frontend pero puerto 3001 (celular en red local, tunnel, etc.)
  return `http://${hostname}:3001/api`
}

// Configuración base de axios
const apiClient = axios.create({
  baseURL: getApiBaseUrl(),
  headers: {
    'Content-Type': 'application/json'
  },
  timeout: 10000 // 10 segundos
})

// Interceptor para requests
apiClient.interceptors.request.use(
  (config) => {
    console.log(`🌐 API Request: ${config.method?.toUpperCase()} ${config.url}`)
    
    // 🔑 Agregar token JWT automáticamente si existe
    const token = localStorage.getItem('bucarabus_token')
    if (token) {
      config.headers['Authorization'] = `Bearer ${token}`
      console.log('🔐 Token JWT agregado al header Authorization')
    }
    
    return config
  },
  (error) => {
    console.error('❌ Request Error:', error)
    return Promise.reject(error)
  }
)

// Interceptor para responses
apiClient.interceptors.response.use(
  (response) => {
    console.log(`✅ API Response: ${response.config.method?.toUpperCase()} ${response.config.url}`)
    return response
  },
  (error) => {
    console.error('❌ Response Error:', error.response?.data || error.message)
    
    // Si el token expiró (401), limpiar sesión y redirigir a login
    if (error.response?.status === 401) {
      const errorCode = error.response?.data?.error_code
      
      if (errorCode === 'TOKEN_EXPIRED' || errorCode === 'INVALID_TOKEN' || errorCode === 'NO_TOKEN') {
        console.warn('Token expirado o inválido. Limpiando sesión...')
        
        // Limpiar localStorage
        localStorage.removeItem('bucarabus_token')
        localStorage.removeItem('bucarabus_user')
        localStorage.removeItem('bucarabus_active_role')
        
        // Redirigir a login (si estamos en el navegador)
        if (typeof window !== 'undefined') {
          window.location.href = '/login'
        }
      }
    }
    
    return Promise.reject(error)
  }
)

export default apiClient
