import express from 'express'
import routesService from '../services/routes.service.js'
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = express.Router()

/**
 * GET /api/routes
 * Obtener todas las rutas
 */
router.get('/', async (req, res) => {
  try {
    const routes = await routesService.getAllRoutes()
    res.json({
      success: true,
      data: routes,
      count: routes.length
    })
  } catch (error) {
    console.error('Error en GET /api/routes:', error)
    res.status(500).json({
      success: false,
      error: 'Error obteniendo rutas',
      message: error.message
    })
  }
})

/**
 * GET /api/routes/search?q=centro
 * Buscar rutas por nombre
 */
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query
    
    if (!q) {
      return res.status(400).json({
        success: false,
        error: 'Parámetro de búsqueda "q" es requerido'
      })
    }
    
    const routes = await routesService.searchRoutes(q)
    res.json({
      success: true,
      data: routes,
      count: routes.length
    })
  } catch (error) {
    console.error('Error en GET /api/routes/search:', error)
    res.status(500).json({
      success: false,
      error: 'Error buscando rutas',
      message: error.message
    })
  }
})

/**
 * GET /api/routes/:id
 * Obtener ruta específica con paradas
 */
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params
    const route = await routesService.getRouteById(id)
    
    if (!route) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: route
    })
  } catch (error) {
    console.error('Error en GET /api/routes/:id:', error)
    res.status(500).json({
      success: false,
      error: 'Error obteniendo ruta',
      message: error.message
    })
  }
})

/**
 * POST /api/routes
 * Crear nueva ruta
 */
router.post('/', requirePermission(PERMISSIONS.CREATE_ROUTES), async (req, res) => {
  try {
    const routeData = req.body
    
    console.log('📥 POST /api/routes - Datos recibidos:', JSON.stringify(routeData, null, 2))
    
    // Validaciones básicas - solo nombre es requerido, ID se genera automáticamente
    if (!routeData.name) {
      console.log('❌ Validación falló: nombre faltante')
      return res.status(400).json({
        success: false,
        error: 'El nombre de la ruta es requerido',
        received: { name: routeData.name }
      })
    }
    
    if (!routeData.path || routeData.path.length < 2) {
      console.log('❌ Validación falló: Path insuficiente')
      return res.status(400).json({
        success: false,
        error: 'Se requieren al menos 2 puntos para la ruta',
        received: { pathLength: routeData.path?.length }
      })
    }
    
    console.log('✅ Validaciones pasadas, creando ruta...')
    const newRoute = await routesService.createRoute(routeData)
    console.log('✅ Ruta creada exitosamente:', newRoute.id)
    
    res.status(201).json({
      success: true,
      data: newRoute,
      message: newRoute.message
    })
  } catch (error) {
    console.error('❌ Error en POST /api/routes:', error)
    console.error('Stack:', error.stack)
    
    if (error.message.includes('Ya existe')) {
      return res.status(409).json({
        success: false,
        error: error.message
      })
    }
    
    res.status(500).json({
      success: false,
      error: 'Error creando ruta',
      message: error.message
    })
  }
})

/**
 * PUT /api/routes/:id
 * Actualizar ruta existente
 */
router.put('/:id', requirePermission(PERMISSIONS.EDIT_ROUTES), async (req, res) => {
  try {
    const { id } = req.params
    const routeData = req.body
    
    const updatedRoute = await routesService.updateRoute(id, routeData)
    
    if (!updatedRoute) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: updatedRoute,
      message: `Ruta ${updatedRoute.name} actualizada exitosamente`
    })
  } catch (error) {
    console.error('Error en PUT /api/routes/:id:', error)
    res.status(500).json({
      success: false,
      error: 'Error actualizando ruta',
      message: error.message
    })
  }
})

/**
 * DELETE /api/routes/:id
 * Desactivar ruta (soft-delete: is_active = FALSE)
 * Para reactivar usar PATCH /:id/toggle con { isActive: true }
 */
router.delete('/:id', requirePermission(PERMISSIONS.DELETE_ROUTES), async (req, res) => {
  try {
    const { id } = req.params
    const userUpdate = req.body?.userUpdate  // opcional: quién desactiva

    // Regla de negocio: verificar viajes activos debe hacerse aquí si aplica
    const result = await routesService.toggleRoute(id, false, userUpdate)

    res.json({
      success: true,
      data: result,
      message: result.message
    })
  } catch (error) {
    console.error('❌ Error en DELETE /api/routes/:id:', error)

    const statusCode = error.code === 'ROUTE_NOT_FOUND' ? 404 : 500

    res.status(statusCode).json({
      success: false,
      error: error.message || 'Error desactivando ruta',
      code:  error.code
    })
  }
})

/**
 * PATCH /api/routes/:id/toggle
 * Activar o desactivar ruta manualmente
 * Body: { isActive: true|false, userUpdate: id }
 */
router.patch('/:id/toggle', requirePermission(PERMISSIONS.EDIT_ROUTES), async (req, res) => {
  try {
    const { id } = req.params
    const { isActive, userUpdate } = req.body

    if (typeof isActive !== 'boolean') {
      return res.status(400).json({
        success: false,
        error: 'El campo isActive (boolean) es requerido'
      })
    }

    const result = await routesService.toggleRoute(id, isActive, userUpdate)

    res.json({
      success: true,
      data: result,
      message: result.message
    })
  } catch (error) {
    console.error('❌ Error en PATCH /api/routes/:id/toggle:', error)

    const statusCode = error.code === 'ROUTE_NOT_FOUND' ? 404 : 500

    res.status(statusCode).json({
      success: false,
      error: error.message || 'Error actualizando estado de ruta',
      code:  error.code
    })
  }
})

/**
 * PATCH /api/routes/:id/visibility
 * Alternar visibilidad de ruta
 */
router.patch('/:id/visibility', requirePermission(PERMISSIONS.EDIT_ROUTES), async (req, res) => {
  try {
    const { id } = req.params
    const result = await routesService.toggleVisibility(id)
    
    if (!result) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: result,
      message: `Visibilidad de ruta ${id} actualizada`
    })
  } catch (error) {
    console.error('Error en PATCH /api/routes/:id/visibility:', error)
    res.status(500).json({
      success: false,
      error: 'Error actualizando visibilidad',
      message: error.message
    })
  }
})


/**
 * GET /api/routes/:id/active-trips-count
 * Obtener cantidad de viajes activos o pendientes de una ruta
 */
router.get('/:id/active-trips-count', async (req, res) => {
  try {
    const result = await routesService.getActiveTripsCount(req.params.id)
    res.json(result)
  } catch (error) {
    console.error('Error al obtener cantidad de viajes activos:', error)
    res.status(500).json({ success: false, error: 'Error interno del servidor', message: error.message })
  }
})

/**
 * GET /api/routes/:id/distance

 * Obtener distancia de ruta en km
 */
router.get('/:id/distance', async (req, res) => {
  try {
    const { id } = req.params
    const result = await routesService.getRouteDistance(id)
    
    if (!result) {
      return res.status(404).json({
        success: false,
        error: 'Ruta no encontrada'
      })
    }
    
    res.json({
      success: true,
      data: result
    })
  } catch (error) {
    console.error('Error en GET /api/routes/:id/distance:', error)
    res.status(500).json({
      success: false,
      error: 'Error calculando distancia',
      message: error.message
    })
  }
})

/**
 * POST /api/routes/:id/points
 * Asignar un punto de ruta existente a esta ruta
 * Body: { idPoint, pointOrder, distFromStart?, etaSeconds? }
 */
router.post('/:id/points', requirePermission(PERMISSIONS.EDIT_ROUTES), async (req, res) => {
  try {
    const { id } = req.params
    const { idPoint, pointOrder, distFromStart, etaSeconds } = req.body

    // Validaciones de frontend
    if (!idPoint) {
      return res.status(400).json({
        success: false,
        error: 'idPoint es requerido'
      })
    }
    if (!pointOrder || Number(pointOrder) < 1) {
      return res.status(400).json({
        success: false,
        error: 'pointOrder debe ser un entero >= 1'
      })
    }

    const result = await routesService.assignRoutePoint(id, {
      idPoint, pointOrder, distFromStart, etaSeconds
    })

    res.status(201).json({
      success: true,
      data:    result,
      message: result.message
    })
  } catch (error) {
    console.error('❌ Error en POST /api/routes/:id/points:', error)

    const statusCode =
      error.code === 'ROUTE_POINT_ASSOC_FK'        ? 404 :
      error.code === 'ROUTE_POINT_ASSOC_DUPLICATE'  ? 409 :
      error.code === 'ROUTE_POINT_ASSOC_ORDER_TAKEN' ? 409 :
      error.code === 'INVALID_PARAM'                ? 400 : 500

    res.status(statusCode).json({
      success: false,
      error:   error.message || 'Error asignando punto a ruta',
      code:    error.code
    })
  }
})

/**
 * PUT /api/routes/:id/points/reorder
 * Reordenar los puntos de una ruta
 * Body: { order: [{idPoint, order}, ...] }
 */
router.put('/:id/points/reorder', requirePermission(PERMISSIONS.EDIT_ROUTES), async (req, res) => {
  try {
    const { id } = req.params
    const { order } = req.body

    if (!Array.isArray(order) || order.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Se requiere un array "order" con al menos un elemento'
      })
    }

    const result = await routesService.reorderRoutePoints(id, order)

    res.json({
      success: true,
      data: result,
      message: result.message
    })
  } catch (error) {
    console.error('❌ Error en PUT /api/routes/:id/points/reorder:', error)
    res.status(500).json({
      success: false,
      error: error.message || 'Error reordenando puntos',
      code: error.code
    })
  }
})

/**
 * GET /api/routes/:id/points
 * Obtener todos los puntos asignados a una ruta
 */
router.get('/:id/points', async (req, res) => {
  try {
    const { id } = req.params
    const points = await routesService.getRoutePoints(id)

    res.json({
      success: true,
      data: points
    })
  } catch (error) {
    console.error('Error en GET /api/routes/:id/points:', error)
    res.status(500).json({
      success: false,
      error: 'Error obteniendo puntos de ruta',
      message: error.message
    })
  }
})

/**
 * DELETE /api/routes/:id/points/:idPoint
 * Desasignar un punto de una ruta
 */
router.delete('/:id/points/:idPoint', requirePermission(PERMISSIONS.EDIT_ROUTES), async (req, res) => {
  try {
    const { id, idPoint } = req.params
    const result = await routesService.unassignRoutePoint(id, idPoint)

    res.json({
      success: true,
      data: result,
      message: result.message
    })
  } catch (error) {
    console.error('Error en DELETE /api/routes/:id/points/:idPoint:', error)
    
    const statusCode = error.code === 'ROUTE_POINT_ASSOC_NOT_FOUND' ? 404 : 500

    res.status(statusCode).json({
      success: false,
      error: error.message || 'Error desasignando punto',
      code: error.code
    })
  }
})

// NOTA: La asignación de buses a rutas ocurre a través de tab_trips,
// no directamente en este módulo. Ver /api/trips para crear viajes
// con id_route + id_bus + id_driver.

export default router
