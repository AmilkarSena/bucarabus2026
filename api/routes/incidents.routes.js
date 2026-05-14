import { Router } from 'express'
import incidentsService from '../services/incidents.service.js'
import { requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = Router()

/**
 * GET /api/incidents
 * Obtiene los incidentes activos
 */
router.get('/', async (req, res) => {
  try {
    const status = req.query.status
    if (status !== 'active') {
      return res.status(400).json({ success: false, error: 'Solo se soporta consulta de incidentes activos (?status=active)' })
    }

    const incidents = await incidentsService.getActiveIncidents()
    res.json({ success: true, data: incidents })
  } catch (error) {
    console.error('Error al obtener incidentes:', error)
    res.status(500).json({ success: false, error: 'Error interno del servidor' })
  }
})

/**
 * POST /api/incidents
 * Crea un nuevo incidente (fallback si socket falla)
 */
router.post('/', requirePermission(PERMISSIONS.CREATE_INCIDENTS), async (req, res) => {
  try {
    const data = req.body
    
    // Validación básica
    if (!data.tripId || !data.incidentId || !data.lat || !data.lng) {
      return res.status(400).json({ success: false, error: 'Faltan datos obligatorios (tripId, incidentId, lat, lng)' })
    }

    const result = await incidentsService.createIncident(data)
    
    // Si la llamada REST es exitosa, emitir el evento socket al instante
    const io = req.app.get('io')
    if (io) {
      io.emit('incident-reported', {
        ...data,
        timestamp: new Date().toISOString()
      })
    }

    res.status(201).json(result)
  } catch (error) {
    console.error('Error al crear incidente:', error)
    res.status(400).json({ success: false, error: error.message })
  }
})

/**
 * PATCH /api/incidents/:id/resolve
 * Resuelve un incidente activo (desde el panel de admin)
 */
router.patch('/:id/resolve', requirePermission(PERMISSIONS.RESOLVE_INCIDENTS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await incidentsService.resolveIncident(id)
    
    // Emitir socket para que los clientes remuevan el pin
    const io = req.app.get('io')
    if (io) {
      io.emit('incident-resolved', { id: parseInt(id, 10) })
    }

    res.json(result)
  } catch (error) {
    console.error('Error al resolver incidente:', error)
    res.status(400).json({ success: false, error: error.message })
  }
})

export default router
