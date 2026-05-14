import express from 'express'
import driversService from '../services/drivers.service.js'
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = express.Router()

/**
 * GET /api/drivers
 * @query active=true  → solo conductores con is_active = TRUE
 */
router.get('/', verifyToken, async (req, res) => {
  try {
    const onlyActive = req.query.active === 'true'
    const result = await driversService.getAllDrivers(onlyActive)
    res.json(result)
  } catch (error) {
    console.error('Error en GET /drivers:', error)
    res.status(500).json({ success: false, message: 'Error al obtener conductores', error: error.message })
  }
})

/**
 * GET /api/drivers/available
 * Conductores activos, sin bus asignado, con licencia vigente (id_status = 1)
 */
router.get('/available', verifyToken, async (req, res) => {
  try {
    const result = await driversService.getAvailableDrivers()
    res.json(result)
  } catch (error) {
    console.error('Error en GET /drivers/available:', error)
    res.status(500).json({ success: false, message: 'Error al obtener conductores disponibles', error: error.message })
  }
})

/**
 * GET /api/drivers/:id
 * Obtener conductor por cédula (id_driver)
 */
router.get('/:id', verifyToken, async (req, res) => {
  try {
    const result = await driversService.getDriverById(req.params.id)
    if (!result.success) return res.status(404).json(result)
    res.json(result)
  } catch (error) {
    console.error('Error en GET /drivers/:id:', error)
    res.status(500).json({ success: false, message: 'Error al obtener conductor', error: error.message })
  }
})

/**
 * POST /api/drivers
 * Crear nuevo conductor
 * Body requerido: { id_driver, name_driver, license_exp }
 * Body opcional:  { birth_date, address_driver, phone_driver, email_driver,
 *                   license_cat, id_eps, id_arl, blood_type, emergency_contact,
 *                   emergency_phone, date_entry, id_status, user_create }
 */
router.post('/', requirePermission(PERMISSIONS.CREATE_DRIVERS), async (req, res) => {
  try {
    const { id_driver, name_driver, license_exp } = req.body

    if (!id_driver || !name_driver || !license_exp) {
      return res.status(400).json({
        success: false,
        message: 'Campos obligatorios: id_driver (cédula), name_driver, license_exp'
      })
    }

    const result = await driversService.createDriver({
      ...req.body,
      user_create: req.body.user_create || 1
    })

    if (!result.success) return res.status(400).json(result)
    res.status(201).json(result)

    // 🔔 Notificar a todos los clientes
    if (req.app.get('io')) {
      req.app.get('io').emit('driver-updated', { action: 'create', id_driver: req.body.id_driver })
    }
  } catch (error) {
    console.error('Error en POST /drivers:', error)
    res.status(500).json({ success: false, message: 'Error al crear conductor', error: error.message })
  }
})

/**
 * PUT /api/drivers/:id
 * Actualizar conductor
 * Body: campos a modificar + { user_update }
 */
router.put('/:id', requirePermission(PERMISSIONS.EDIT_DRIVERS), async (req, res) => {
  try {
    const result = await driversService.updateDriver(req.params.id, {
      ...req.body,
      user_update: req.body.user_update || 1
    })

    if (!result.success) return res.status(400).json(result)
    res.json(result)

    // 🔔 Notificar a todos los clientes
    if (req.app.get('io')) {
      req.app.get('io').emit('driver-updated', { action: 'update', id_driver: req.params.id })
    }
  } catch (error) {
    console.error('Error en PUT /drivers/:id:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar conductor', error: error.message })
  }
})

/**
 * PATCH /api/drivers/:id/status
 * Activar / inactivar conductor (is_active)
 * Body: { is_active: boolean, user_update? }
 */
router.patch('/:id/status', requirePermission(PERMISSIONS.EDIT_DRIVERS), async (req, res) => {
  try {
    const { is_active, user_update } = req.body

    if (typeof is_active !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'El campo "is_active" es requerido y debe ser boolean'
      })
    }

    const result = await driversService.toggleStatus(req.params.id, is_active, user_update || 1)
    if (!result.success) return res.status(400).json(result)
    res.json(result)

    // 🔔 Notificar a todos los clientes
    if (req.app.get('io')) {
      req.app.get('io').emit('driver-updated', { action: 'status_change', id_driver: req.params.id })
    }
  } catch (error) {
    console.error('Error en PATCH /drivers/:id/status:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado', error: error.message })
  }
})

/**
 * POST /api/drivers/:id/account
 * Vincular conductor con un usuario existente
 * Body: { id_user, assigned_by? }
 */
router.post('/:id/account', requirePermission(PERMISSIONS.EDIT_DRIVERS), async (req, res) => {
  try {
    const { id_user, assigned_by } = req.body
    if (!id_user) {
      return res.status(400).json({ success: false, message: 'El campo id_user es requerido' })
    }
    const result = await driversService.linkAccount(
      req.params.id,
      id_user,
      assigned_by || req.user?.id_user || 1
    )
    if (!result.success) return res.status(400).json(result)
    res.status(201).json(result)
  } catch (error) {
    console.error('Error en POST /drivers/:id/account:', error)
    res.status(500).json({ success: false, message: 'Error al vincular cuenta', error: error.message })
  }
})

/**
 * DELETE /api/drivers/:id/account
 * Desvincular cuenta del conductor
 * Body: { unlinked_by? }
 */
router.delete('/:id/account', requirePermission(PERMISSIONS.EDIT_DRIVERS), async (req, res) => {
  try {
    const result = await driversService.unlinkAccount(
      req.params.id,
      req.body.unlinked_by || req.user?.id_user || 1
    )
    if (!result.success) return res.status(400).json(result)
    res.json(result)
  } catch (error) {
    console.error('Error en DELETE /drivers/:id/account:', error)
    res.status(500).json({ success: false, message: 'Error al desvincular cuenta', error: error.message })
  }
})

/**
 * DELETE /api/drivers/:id
 * Soft delete (is_active = FALSE, id_status = 7)
 * Body: { user_update? }
 */
router.delete('/:id', requirePermission(PERMISSIONS.DELETE_DRIVERS), async (req, res) => {
  try {
    const result = await driversService.deleteDriver(req.params.id, req.body.user_update || 1)
    if (!result.success) return res.status(400).json(result)
    res.json(result)

    // 🔔 Notificar a todos los clientes
    if (req.app.get('io')) {
      req.app.get('io').emit('driver-updated', { action: 'delete', id_driver: req.params.id })
    }
  } catch (error) {
    console.error('Error en DELETE /drivers/:id:', error)
    res.status(500).json({ success: false, message: 'Error al eliminar conductor', error: error.message })
  }
})

export default router
