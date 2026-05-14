import express from 'express'
import pool from '../config/database.js'
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = express.Router()

/**
 * GET /api/roles/permissions
 * Obtiene el catálogo maestro de todos los permisos estructurados
 */
router.get('/permissions', verifyToken, requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        id_permission,
        code_permission,
        name_permission,
        descrip_permission,
        id_parent
      FROM tab_permissions
      WHERE is_active = TRUE
      ORDER BY id_parent NULLS FIRST, id_permission
    `)
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error fetching permissions:', error)
    res.status(500).json({ success: false, message: 'Error al obtener permisos' })
  }
})

/**
 * GET /api/roles/:id/permissions
 * Obtiene los permisos asignados a un rol específico
 */
router.get('/:id/permissions', verifyToken, requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const roleId = parseInt(req.params.id)
    const result = await pool.query(`
      SELECT p.code_permission
      FROM tab_role_permissions rp
      JOIN tab_permissions p ON rp.id_permission = p.id_permission
      WHERE rp.id_role = $1 AND p.is_active = TRUE
    `, [roleId])
    
    // Devolvemos solo el arreglo de códigos: ['VIEW_BUSES', 'CREATE_BUSES', ...]
    const permissions = result.rows.map(row => row.code_permission)
    res.json({ success: true, data: permissions })
  } catch (error) {
    console.error('Error fetching role permissions:', error)
    res.status(500).json({ success: false, message: 'Error al obtener permisos del rol' })
  }
})

/**
 * PUT /api/roles/:id/permissions
 * Actualiza masivamente los permisos de un rol
 */
router.put('/:id/permissions', verifyToken, requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const roleId = parseInt(req.params.id)
    const { permissions } = req.body // Espera un arreglo ['VIEW_BUSES', 'MODULE_TRIPS', ...]
    const userUpdate = req.user.id_user // Obtenido del token

    if (!Array.isArray(permissions)) {
      return res.status(400).json({ success: false, message: 'El formato de permisos es inválido. Se esperaba un arreglo.' })
    }

    const result = await pool.query(
      'SELECT fun_update_role_permissions($1, $2::jsonb, $3) as success',
      [roleId, JSON.stringify(permissions), userUpdate]
    )

    if (result.rows[0].success) {
      res.json({ success: true, message: 'Permisos actualizados correctamente' })
    } else {
      res.status(400).json({ success: false, message: 'No se pudieron actualizar los permisos' })
    }
  } catch (error) {
    console.error('Error updating role permissions:', error)
    res.status(500).json({ success: false, message: 'Error interno del servidor al actualizar permisos' })
  }
})

export default router
