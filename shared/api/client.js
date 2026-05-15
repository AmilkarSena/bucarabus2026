import axios from 'axios'

/**
 * Cliente HTTP compartido entre App Admin y App Conductor.
 * Maneja el token JWT automáticamente en cada request.
 */
const getApiBaseUrl = () => {
  if (import.meta.env.VITE_API_URL) return import.meta.env.VITE_API_URL
  const hostname = window.location.hostname
  if (hostname === 'localhost' || hostname === '127.0.0.1') return 'http://localhost:3001/api'
  return `http://${hostname}:3001/api`
}

const apiClient = axios.create({
  baseURL: getApiBaseUrl(),
  headers: { 'Content-Type': 'application/json' },
  timeout: 10000
})

// Añadir token JWT automáticamente en cada request
apiClient.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('bucarabus_token')
    if (token) config.headers['Authorization'] = `Bearer ${token}`
    return config
  },
  (error) => Promise.reject(error)
)

// Manejar token expirado globalmente
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      const errorCode = error.response?.data?.error_code
      if (errorCode === 'TOKEN_EXPIRED' || errorCode === 'INVALID_TOKEN' || errorCode === 'NO_TOKEN') {
        localStorage.removeItem('bucarabus_token')
        localStorage.removeItem('bucarabus_user')
        localStorage.removeItem('bucarabus_active_role')
        if (typeof window !== 'undefined') {
          const base = import.meta.env.BASE_URL || '/'
          window.location.href = `${base}login`
        }
      }
    }
    return Promise.reject(error)
  }
)

export default apiClient
