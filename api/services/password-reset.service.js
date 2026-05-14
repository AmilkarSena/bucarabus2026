import crypto from 'crypto'
import bcrypt from 'bcrypt'
import pool from '../config/database.js'
import emailService from './email.service.js'

const SALT_ROUNDS  = 10
const FRONTEND_URL = process.env.FRONTEND_URL || 'http://localhost:3002'

/**
 * Inicia el flujo de recuperación de contraseña.
 * - Busca el usuario por email (SELECT en servicio — es lectura, no mutación)
 * - Genera un token seguro
 * - Llama a fun_create_password_reset_token (mutación atómica en BD)
 * - Envía el correo con el enlace
 *
 * Por seguridad retorna siempre success:true aunque el email no exista.
 */
async function requestPasswordReset(email) {
  // 1. Buscar usuario (lectura — vive en el servicio)
  const userResult = await pool.query(
    `SELECT id_user, full_name, email_user
     FROM tab_users
     WHERE LOWER(email_user) = LOWER($1) AND is_active = TRUE`,
    [email.trim()]
  )

  if (userResult.rows.length > 0) {
    const user = userResult.rows[0]

    // 2. Generar token criptográficamente seguro
    const token     = crypto.randomBytes(48).toString('hex')
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000) // 1 hora

    // 3. Persistir token (DELETE old + INSERT new) — mutación via función almacenada
    const { rows } = await pool.query(
      `SELECT success, msg, error_code
       FROM fun_create_password_reset_token($1, $2, $3)`,
      [user.id_user, token, expiresAt]
    )

    if (!rows[0].success) {
      throw new Error(rows[0].msg)
    }

    // 4. Enviar correo con el enlace
    const resetUrl = `${FRONTEND_URL}/reset-password?token=${token}`
    await emailService.sendPasswordResetEmail(user.email_user, resetUrl, user.full_name)

    console.log(`✉️ Correo de recuperación enviado a: ${user.email_user}`)
  }

  // Siempre retornar éxito (previene user enumeration)
  return { success: true }
}

/**
 * Valida si un token existe y no ha expirado (lectura — vive en el servicio).
 * @returns {{ valid: boolean }}
 */
async function validateResetToken(token) {
  const result = await pool.query(
    `SELECT id_token FROM tab_password_reset_tokens
     WHERE token = $1 AND expires_at > NOW()`,
    [token]
  )
  return { valid: result.rows.length > 0 }
}

/**
 * Restablece la contraseña usando el token.
 * - Hashea la nueva contraseña (lógica de negocio — vive en el servicio)
 * - Llama a fun_consume_password_reset_token (validar + UPDATE + DELETE, atómico en BD)
 */
async function resetPassword(token, newPassword) {
  // Hashear la contraseña (lógica de negocio)
  const passwordHash = await bcrypt.hash(newPassword, SALT_ROUNDS)

  // Consumir el token y actualizar la contraseña — mutación via función almacenada
  const { rows } = await pool.query(
    `SELECT success, msg, error_code
     FROM fun_consume_password_reset_token($1, $2)`,
    [token, passwordHash]
  )

  return rows[0] // { success, msg, error_code }
}

export default { requestPasswordReset, validateResetToken, resetPassword }
