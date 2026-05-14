import express from 'express'
import pool from '../config/database.js'
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = express.Router()

/**
 * GET /api/users/:id/permissions/overrides
 * Retorna los overrides individuales del usuario: [{code_permission, is_granted}]
 * Los permisos efectivos ya viajan en el JWT; este endpoint es para la UI de gestión.
 */
router.get('/:id/permissions/overrides', verifyToken, requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({ success: false, message: 'ID de usuario inválido' })
    }

    const result = await pool.query(
      `SELECT p.code_permission, up.is_granted
       FROM tab_user_permissions up
       JOIN tab_permissions p ON up.id_permission = p.id_permission
       WHERE up.id_user = $1
       ORDER BY p.code_permission`,
      [userId]
    )

    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error en GET /api/users/:id/permissions/overrides:', error)
    res.status(500).json({ success: false, message: 'Error al obtener overrides del usuario' })
  }
})

/**
 * PUT /api/users/:id/permissions/overrides
 * Actualiza los overrides individuales del usuario (reemplazo atómico).
 * Body: { overrides: [{ code: 'CREATE_BUSES', is_granted: true }, ...] }
 * Llama a fun_update_user_permissions para ejecutar el DELETE + INSERT atómico.
 */
router.put('/:id/permissions/overrides', verifyToken, requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({ success: false, message: 'ID de usuario inválido' })
    }

    const { overrides } = req.body
    const adminId = req.user.id_user

    if (!Array.isArray(overrides)) {
      return res.status(400).json({
        success: false,
        message: 'El formato de overrides es inválido. Se esperaba un arreglo.'
      })
    }

    const result = await pool.query(
      `SELECT success, msg, error_code
       FROM fun_update_user_permissions($1, $2::jsonb, $3)`,
      [userId, JSON.stringify(overrides), adminId]
    )

    const { success, msg, error_code } = result.rows[0]

    if (!success) {
      return res.status(400).json({ success: false, message: msg, error_code })
    }

    res.json({ success: true, message: msg })
  } catch (error) {
    console.error('Error en PUT /api/users/:id/permissions/overrides:', error)
    res.status(500).json({ success: false, message: 'Error interno al actualizar overrides' })
  }
})

export default router
