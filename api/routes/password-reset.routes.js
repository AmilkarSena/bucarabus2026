import express from 'express'
import passwordResetService from '../services/password-reset.service.js'

const router = express.Router()

/**
 * POST /api/auth/forgot-password
 * Body: { email }
 * Siempre retorna 200 (seguridad: no revelar si el email existe).
 */
router.post('/forgot-password', async (req, res) => {
  const { email } = req.body

  if (!email) {
    return res.status(400).json({ success: false, message: 'El email es requerido' })
  }

  try {
    await passwordResetService.requestPasswordReset(email)
    res.json({
      success: true,
      message: 'Si el correo está registrado, recibirás las instrucciones en breve.'
    })
  } catch (error) {
    console.error('❌ Error en forgot-password:', error)
    res.status(500).json({ success: false, message: 'Error al procesar la solicitud' })
  }
})

/**
 * GET /api/auth/validate-reset-token?token=xxx
 * Verifica si un token es válido antes de mostrar el formulario de nueva contraseña.
 */
router.get('/validate-reset-token', async (req, res) => {
  const { token } = req.query

  if (!token) {
    return res.status(400).json({ success: false, valid: false })
  }

  try {
    const result = await passwordResetService.validateResetToken(token)
    res.json({ success: true, ...result })
  } catch (error) {
    console.error('❌ Error en validate-reset-token:', error)
    res.status(500).json({ success: false, valid: false })
  }
})

/**
 * POST /api/auth/reset-password
 * Body: { token, newPassword }
 */
router.post('/reset-password', async (req, res) => {
  const { token, newPassword } = req.body

  if (!token || !newPassword) {
    return res.status(400).json({
      success: false,
      message: 'Token y nueva contraseña son requeridos'
    })
  }

  if (newPassword.length < 8) {
    return res.status(400).json({
      success: false,
      message: 'La contraseña debe tener al menos 8 caracteres'
    })
  }

  try {
    const result = await passwordResetService.resetPassword(token, newPassword)

    if (!result.success) {
      return res.status(400).json({ success: false, message: result.msg })
    }

    res.json({ success: true, message: result.msg })
  } catch (error) {
    console.error('❌ Error en reset-password:', error)
    res.status(500).json({ success: false, message: 'Error al restablecer la contraseña' })
  }
})

export default router
