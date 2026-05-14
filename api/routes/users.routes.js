import express from 'express'
import usersService from '../services/users.service.js'
import { verifyToken, requirePermission, verifySelfOrAdmin } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const SYSTEM_USER_ID = -1;
const router = express.Router()

/**
 * GET /api/users
 * Obtener todos los usuarios (con filtros opcionales)
 * ⚠️ Requiere autenticación
 * Query params:
 * - role: ID del rol para filtrar
 * - active: true/false para filtrar por estado
 */
router.get('/', verifyToken, async (req, res) => {
  try {
    const filters = {}
    
    if (req.query.role) {
      filters.role = parseInt(req.query.role)
    }
    
    if (req.query.active !== undefined) {
      filters.active = req.query.active === 'true'
    }

    const result = await usersService.getAllUsers(filters)

    if (!result.success) {
      return res.status(500).json({
        success: false,
        message: result.message,
        error: result.error
      })
    }

    res.json({
      success: true,
      data: result.data,
      count: result.count
    })
  } catch (error) {
    console.error('Error en GET /api/users:', error)
    res.status(500).json({
      success: false,
      message: 'Error al obtener usuarios',
      error: error.message
    })
  }
})

/**
 * GET /api/users/:id
 * Obtener usuario por ID (con sus roles)
 * ⚠️ Solo puedes ver tus propios datos o si eres admin
 */
router.get('/:id', verifySelfOrAdmin, async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const result = await usersService.getUserById(userId)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data
    })
  } catch (error) {
    console.error('Error en GET /api/users/:id:', error)
    res.status(500).json({
      success: false,
      message: 'Error al obtener usuario',
      error: error.message
    })
  }
})

/**
 * POST /api/users
 * Crear nuevo usuario
 * ⚠️ Solo admins pueden crear usuarios
 * Body:
 * - email (required)
 * - password (required, min 8 chars, mayúscula + minúscula + número)
 * - full_name (required, 2-100 chars)
 * - id_role (required, 1=Administrador, 2=Turnador, 3=Conductor)
 */
router.post('/', requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const { email, password, full_name, id_role } = req.body

    if (!email || !password || !full_name || !id_role) {
      return res.status(400).json({
        success: false,
        message: 'Email, contraseña, nombre completo y rol son requeridos'
      })
    }

    const result = await usersService.createUser({
      email,
      password,
      full_name,
      id_role: parseInt(id_role),
      user_create: req.user.id_user
    })

    if (!result.success) {
      return res.status(400).json(result)
    }

    res.status(201).json(result)
  } catch (error) {
    console.error('Error en POST /api/users:', error)
    res.status(500).json({
      success: false,
      message: 'Error al crear usuario',
      error: error.message
    })
  }
})

/**
 * PUT /api/users/:id
 * Actualizar usuario (nombre y avatar)
 * ⚠️ Solo puedes actualizar tus propios datos o si eres admin
 * Body:
 * - full_name (optional, 3-100 chars, solo letras y espacios)
 * - avatar_url (optional)
 */
router.put('/:id', verifySelfOrAdmin, async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { full_name, avatar_url, user, id_gender, birth_date, phone } = req.body

    if (!full_name && avatar_url === undefined && id_gender === undefined && birth_date === undefined && phone === undefined) {
      return res.status(400).json({
        success: false,
        message: 'Debe proporcionar al menos un campo para actualizar'
      })
    }

    // Usar el ID del usuario autenticado como auditor
    const auditor = user || req.user?.id_user || SYSTEM_USER_ID

    // El servicio realizará validaciones robustas del nombre si se proporciona
    const result = await usersService.updateUser(userId, {
      full_name,
      avatar_url,
      user_update: auditor,
      id_gender,
      birth_date,
      phone
    })

    if (!result.success) {
      const statusCode = result.notFound ? 404 : 400
      return res.status(statusCode).json({
        success: false,
        message: result.message,
        error_code: result.error_code
      })
    }

    res.json({
      success: true,
      data: result.data,
      message: result.message
    })
  } catch (error) {
    console.error('Error en PUT /api/users/:id:', error)
    res.status(500).json({
      success: false,
      message: 'Error al actualizar usuario',
      error: error.message
    })
  }
})

/**
 * PUT /api/users/:id/password
 * Cambiar contraseña de usuario
 * ⚠️ Solo puedes cambiar tu propia contraseña o si eres admin
 * Body:
 * - newPassword (required, min 8 chars, debe tener mayúscula, minúscula y número)
 */
router.put('/:id/password', verifySelfOrAdmin, async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { newPassword } = req.body

    if (!newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Nueva contraseña es requerida'
      })
    }

    // El servicio realizará validaciones robustas de la contraseña
    const result = await usersService.changePassword(userId, newPassword)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      message: result.message
    })
  } catch (error) {
    console.error('Error en PUT /api/users/:id/password:', error)
    res.status(500).json({
      success: false,
      message: 'Error al cambiar contraseña',
      error: error.message
    })
  }
})

/**
 * PUT /api/users/:id/status
 * Activar/Desactivar usuario
 * ⚠️ Solo admins pueden cambiar estado de usuarios
 * Body:
 * - isActive (required, boolean)
 */
router.put('/:id/status', requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { isActive } = req.body

    if (typeof isActive !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'isActive debe ser un valor booleano'
      })
    }

    const result = await usersService.toggleUserStatus(userId, isActive)

    if (!result.success) {
      return res.status(404).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data,
      message: result.message
    })
  } catch (error) {
    console.error('Error en PUT /api/users/:id/status:', error)
    res.status(500).json({
      success: false,
      message: 'Error al cambiar estado del usuario',
      error: error.message
    })
  }
})

/**
 * GET /api/users/:id/roles
 * Obtener roles de un usuario
 * ⚠️ Solo puedes ver tus propios roles o si eres admin
 */
router.get('/:id/roles', verifySelfOrAdmin, async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const result = await usersService.getUserRoles(userId)

    if (!result.success) {
      return res.status(500).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      data: result.data
    })
  } catch (error) {
    console.error('Error en GET /api/users/:id/roles:', error)
    res.status(500).json({
      success: false,
      message: 'Error al obtener roles del usuario',
      error: error.message
    })
  }
})

/**
 * POST /api/users/:id/roles
 * Asignar rol a usuario
 * ⚠️ Solo admins pueden asignar roles
 * Body:
 * - roleId (required, 1=Pasajero, 2=Conductor, 3=Supervisor, 4=Admin)
 * - assignedBy (optional, ID del usuario que asigna)
 */
router.post('/:id/roles', requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const userId = parseInt(req.params.id)

    if (isNaN(userId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario inválido'
      })
    }

    const { roleId, assignedBy } = req.body

    if (!roleId) {
      return res.status(400).json({
        success: false,
        message: 'roleId es requerido'
      })
    }

    const result = await usersService.assignRole(userId, roleId, assignedBy)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.status(201).json({
      success: true,
      message: result.message
    })
  } catch (error) {
    console.error('Error en POST /api/users/:id/roles:', error)
    res.status(500).json({
      success: false,
      message: 'Error al asignar rol',
      error: error.message
    })
  }
})

/**
 * DELETE /api/users/:id/roles/:roleId
 * Quitar rol de usuario
 * ⚠️ Solo admins pueden quitar roles
 */
router.delete('/:id/roles/:roleId', requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {
  try {
    const userId = parseInt(req.params.id)
    const roleId = parseInt(req.params.roleId)

    if (isNaN(userId) || isNaN(roleId)) {
      return res.status(400).json({
        success: false,
        message: 'ID de usuario o rol inválido'
      })
    }

    const result = await usersService.removeRole(userId, roleId)

    if (!result.success) {
      return res.status(400).json({
        success: false,
        message: result.message
      })
    }

    res.json({
      success: true,
      message: result.message
    })
  } catch (error) {
    console.error('Error en DELETE /api/users/:id/roles/:roleId:', error)
    res.status(500).json({
      success: false,
      message: 'Error al quitar rol',
      error: error.message
    })
  }
})

export default router
