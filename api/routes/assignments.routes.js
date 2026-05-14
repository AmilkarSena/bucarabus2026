import express from 'express'
import assignmentsService from '../services/assignments.service.js'
import { requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = express.Router()

/**
 * POST /api/assignments
 * Body: { id_bus, id_driver }
 * assigned_by se toma del usuario autenticado (req.user.id_user)
 */
router.post('/', requirePermission(PERMISSIONS.MANAGE_ASSIGNMENTS), async (req, res) => {
  try {
    const { id_bus, id_driver } = req.body
    const assignedBy = req.user.id_user

    if (!id_bus || !id_driver) {
      return res.status(400).json({ success: false, message: 'id_bus e id_driver son requeridos' })
    }

    const idBus = parseInt(id_bus)
    if (isNaN(idBus)) {
      return res.status(400).json({ success: false, message: 'id_bus debe ser un número entero' })
    }

    const result = await assignmentsService.assignDriver(idBus, id_driver, assignedBy)

    if (!result.success) {
      return res.status(400).json(result)
    }
    res.status(201).json(result)
  } catch (error) {
    res.status(500).json({ success: false, message: error.message })
  }
})

/**
 * GET /api/assignments/active/:id_bus - Asignación activa de un bus
 */
router.get('/active/:id_bus', requirePermission(PERMISSIONS.MANAGE_ASSIGNMENTS), async (req, res) => {
  try {
    const idBus = parseInt(req.params.id_bus)
    if (isNaN(idBus)) {
      return res.status(400).json({ success: false, message: 'id_bus debe ser un número entero' })
    }
    const result = await assignmentsService.getActiveAssignment(idBus)
    res.json(result)
  } catch (error) {
    res.status(500).json({ success: false, message: error.message })
  }
})

/**
 * GET /api/assignments/bus/:id_bus - Historial completo de un bus
 */
router.get('/bus/:id_bus', requirePermission(PERMISSIONS.MANAGE_ASSIGNMENTS), async (req, res) => {
  try {
    const idBus = parseInt(req.params.id_bus)
    if (isNaN(idBus)) {
      return res.status(400).json({ success: false, message: 'id_bus debe ser un número entero' })
    }
    const result = await assignmentsService.getBusHistory(idBus)
    res.json(result)
  } catch (error) {
    res.status(500).json({ success: false, message: error.message })
  }
})

/**
 * DELETE /api/assignments/:id_driver - Desasignar conductor activo
 * unassigned_by se toma del usuario autenticado (req.user.id_user)
 */
router.delete('/:id_driver', requirePermission(PERMISSIONS.MANAGE_ASSIGNMENTS), async (req, res) => {
  try {
    const idDriver = parseInt(req.params.id_driver)
    const unassignedBy = req.user.id_user

    if (isNaN(idDriver)) {
      return res.status(400).json({ success: false, message: 'id_driver debe ser un número' })
    }

    const result = await assignmentsService.unassignDriver(idDriver, unassignedBy)

    if (!result.success) {
      return res.status(400).json(result)
    }
    res.json(result)
  } catch (error) {
    res.status(500).json({ success: false, message: error.message })
  }
})

export default router
