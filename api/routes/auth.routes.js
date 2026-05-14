import express from 'express'
import authService from '../services/auth.service.js'
import { verifyToken, verifyAdmin } from '../middlewares/auth.middleware.js'

const router = express.Router()

/**
 * Validar formato de email mediante regex
 * @param {string} email - Email a validar
 * @returns {boolean}
 */
function isValidEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
  return emailRegex.test(email)
}

/**
 * @route   POST /api/auth/login
 * @desc    Autenticar usuario
 * @body    { email, password }
 */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body
    
    console.log('🔵 POST /api/auth/login')
    console.log('   Email:', email)
    
    // Validar campos requeridos
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email y contraseña son requeridos',
        error_code: 'MISSING_CREDENTIALS'
      })
    }

    // Validar formato básico del email
    if (!isValidEmail(email.trim())) {
      return res.status(400).json({
        success: false,
        message: 'Formato de email inválido',
        error_code: 'INVALID_EMAIL_FORMAT'
      })
    }
    
    // Llamar al servicio de autenticación
    const result = await authService.login(email, password)
    
    if (result.success) {
      return res.json(result)
    } else {
      // Retornar 401 para credenciales inválidas
      return res.status(401).json(result)
    }
    
  } catch (error) {
    console.error('❌ Error en POST /api/auth/login:', error)
    res.status(500).json({
      success: false,
      message: 'Error del servidor',
      error: error.message
    })
  }
})

/**
 * @route   POST /api/auth/me
 * @desc    Obtener datos del usuario actual por email (refresh de sesión)
 * @body    { email }
 */
router.post('/me', verifyToken, async (req, res) => {
  try {
    const email = req.user?.email
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email no disponible en el token'
      })
    }

    const result = await authService.getUserByEmail(email)

    if (!result.success) {
      return res.status(404).json(result)
    }

    res.json(result)
  } catch (error) {
    console.error('❌ Error en POST /api/auth/me:', error)
    res.status(500).json({
      success: false,
      message: 'Error del servidor',
      error: error.message
    })
  }
})

/**
 * @route   POST /api/auth/check-email
 * @desc    Verificar si un email existe
 * @body    { email }
 */
router.post('/check-email', verifyAdmin, async (req, res) => {
  try {
    if (process.env.NODE_ENV === 'production') {
      return res.status(404).json({
        success: false,
        message: 'Endpoint no disponible'
      })
    }

    const { email } = req.body
    
    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email es requerido'
      })
    }

    // Validar formato básico del email antes de consultar la BD
    if (!isValidEmail(email.trim())) {
      return res.status(400).json({
        success: false,
        message: 'Formato de email inválido',
        error_code: 'INVALID_EMAIL_FORMAT'
      })
    }
    
    const exists = await authService.emailExists(email.trim())
    
    res.json({
      success: true,
      exists
    })
    
  } catch (error) {
    console.error('Error en POST /api/auth/check-email:', error)
    res.status(500).json({
      success: false,
      message: 'Error del servidor',
      error: error.message
    })
  }
})

export default router
