import express from 'express'
import busesService from '../services/buses.service.js'
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'
import { busSchema } from '../../shared/validations/bus.schema.js'

// Helper para formatear errores Zod (versión segura sin forEach sobre null)
const formatZodErrors = (zodError) => {
  const formatted = {}
  const issues = zodError.issues || zodError.errors || []
  issues.forEach(err => {
    const field = err.path[0]
    formatted[field] = err.message
  })
  return formatted
}

const router = express.Router()

/**
 * @route   GET /api/buses/passenger
 * @desc    Endpoint público minimalista para pasajeros
 */
router.get('/passenger', async (req, res) => {
  try {
    const result = await busesService.getPassengerActiveBuses();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/passenger:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses para pasajeros',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses
 * @desc    Obtener todos los buses
 * @query   active - true/false para filtrar solo activos
 */
router.get('/', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const onlyActive = req.query.active === 'true';
    const result = await busesService.getAllBuses(onlyActive);
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/available
 * @desc    Obtener buses disponibles (activos y sin conductor)
 */
router.get('/available', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getAvailableBuses();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/available:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses disponibles',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/stats
 * @desc    Obtener estadísticas de buses
 */
router.get('/stats', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getBusStats();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/stats:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener estadísticas',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/expiring
 * @desc    Obtener buses con documentos próximos a vencer
 * @query   days - Número de días (default: 30)
 */
router.get('/expiring', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const days = parseInt(req.query.days) || 30;
    const result = await busesService.getBusesWithExpiringDocs(days);
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/expiring:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener buses con documentos por vencer',
      error: error.message
    });
  }
});

/**
 * @route   GET /api/buses/insurance-types
 * @desc    Tipos de seguro activos (para formularios de alta)
 */
router.get('/insurance-types', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getActiveInsuranceTypes();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/insurance-types:', error);
    res.status(500).json({ success: false, message: 'Error al obtener tipos de seguro', error: error.message });
  }
});

/**
 * @route   GET /api/buses/insurers
 * @desc    Aseguradoras activas (para formularios de alta)
 */
router.get('/insurers', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getActiveInsurers();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/insurers:', error);
    res.status(500).json({ success: false, message: 'Error al obtener aseguradoras', error: error.message });
  }
});

/**
 * @route   GET /api/buses/transit-doc-types
 * @desc    Tipos de documentos de tránsito activos (para formularios de alta)
 */
router.get('/transit-doc-types', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getActiveTransitDocTypes();
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/transit-doc-types:', error);
    res.status(500).json({ success: false, message: 'Error al obtener tipos de documento', error: error.message });
  }
});

/**
 * @route   GET /api/buses/:plate
 * @desc    Obtener bus por placa
 */
router.get('/:plate', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const { plate } = req.params;
    const result = await busesService.getBusByPlate(plate);
    
    if (!result.success) {
      return res.status(404).json(result);
    }
    
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/:plate:', error);
    res.status(500).json({
      success: false,
      message: 'Error al obtener bus',
      error: error.message
    });
  }
});

/**
 * @route   POST /api/buses
 * @desc    Crear nuevo bus
 * @access  Admin
 * @body    {
 *   plate_number, amb_code, code_internal, id_company,
 *   model_year, capacity_bus, color_bus, id_owner,
 *   brand_bus?, model_name?, chassis_number?, photo_url?, gps_device_id?
 * }
 * @note    user_create se toma del JWT — no enviarlo en el body
 */
router.post('/', requirePermission(PERMISSIONS.CREATE_BUSES), async (req, res) => {
  try {
    const validation = busSchema.safeParse(req.body)
    
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        message: 'Errores de validación',
        errors: formatZodErrors(validation.error)
      })
    }

    // user_create viene del JWT, no del body (evita suplantación)
    const busData = {
      ...validation.data,
      user_create: req.user.id_user
    };

    const result = await busesService.createBus(busData);

    if (!result.success) {
      return res.status(400).json(result);
    }

    res.status(201).json(result);
    // 🔔 Notificar a todos los clientes conectados
    if (req.app.get('io')) {
      req.app.get('io').emit('bus-updated', { action: 'create', plate_number: result.data?.plate_number });
    }
  } catch (error) {
    console.error('Error en POST /buses:', error);
    res.status(500).json({
      success: false,
      message: 'Error al crear bus',
      error: error.message
    });
  }
});

/**
 * @route   PUT /api/buses/:plate
 * @desc    Actualizar datos del bus
 * @access  Admin
 * @body    {
 *   amb_code?, code_internal?, id_company?, model_year?,
 *   capacity_bus?, color_bus?, id_owner?,
 *   brand_bus?, model_name?, chassis_number?, photo_url?, gps_device_id?
 * }
 * @note    user_update se toma del JWT — no enviarlo en el body
 */
router.put('/:plate', requirePermission(PERMISSIONS.EDIT_BUSES), async (req, res) => {
  try {
    const { plate } = req.params;
    
    // Validar payload
    const validation = busSchema.safeParse(req.body)
    
    if (!validation.success) {
      return res.status(400).json({
        success: false,
        message: 'Errores de validación',
        errors: formatZodErrors(validation.error)
      })
    }

    const busData = {
      ...validation.data,
      user_update: req.user.id_user  // viene del JWT
    };
    const result = await busesService.updateBus(plate, busData);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
    // 🔔 Notificar a todos los clientes conectados
    if (req.app.get('io')) {
      req.app.get('io').emit('bus-updated', { action: 'update', plate_number: plate });
    }
  } catch (error) {
    console.error('Error en PUT /buses/:plate:', error);
    res.status(500).json({
      success: false,
      message: 'Error al actualizar bus',
      error: error.message
    });
  }
});

/**
 * @route   PATCH /api/buses/:plate/status
 * @desc    Activar o desactivar un bus
 * @access  Admin
 * @body    { is_active: boolean }
 * @note    user_update se toma del JWT — no enviarlo en el body
 */
router.patch('/:plate/status', requirePermission(PERMISSIONS.EDIT_BUSES), async (req, res) => {
  try {
    const { plate } = req.params;
    const { is_active } = req.body;
    
    if (typeof is_active !== 'boolean') {
      return res.status(400).json({
        success: false,
        message: 'El campo is_active es requerido y debe ser boolean'
      });
    }
    
    const result = await busesService.toggleBusStatus(plate, is_active, req.user.id_user);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
    // 🔔 Notificar a todos los clientes conectados
    if (req.app.get('io')) {
      req.app.get('io').emit('bus-updated', { action: 'status_change', plate_number: plate });
    }
  } catch (error) {
    console.error('Error en PATCH /buses/:plate/status:', error);
    res.status(500).json({
      success: false,
      message: 'Error al cambiar estado del bus',
      error: error.message
    });
  }
});

/**
 * @route   DELETE /api/buses/:plate
 * @desc    Eliminar bus (soft delete)
 * @access  Admin
 * @note    user_update se toma del JWT — no se necesita body
 */
router.delete('/:plate', requirePermission(PERMISSIONS.DELETE_BUSES), async (req, res) => {
  try {
    const { plate } = req.params;
    const result = await busesService.toggleBusStatus(plate, false, req.user.id_user);
    
    if (!result.success) {
      return res.status(400).json(result);
    }
    
    res.json(result);
    // 🔔 Notificar a todos los clientes conectados
    if (req.app.get('io')) {
      req.app.get('io').emit('bus-updated', { action: 'delete', plate_number: plate });
    }
  } catch (error) {
    console.error('Error en DELETE /buses/:plate:', error);
    res.status(500).json({
      success: false,
      message: 'Error al eliminar bus',
      error: error.message
    });
  }
});

// ─── Seguros por bus ─────────────────────────────────────────────────────────

/**
 * @route   GET /api/buses/:plate/insurance
 * @desc    Listar todas las pólizas de un bus
 */
router.get('/:plate/insurance', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getBusInsurance(req.params.plate);
    if (!result.success) {
      const status = result.error_code === 'BUS_NOT_FOUND' ? 404 : 400;
      return res.status(status).json(result);
    }
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/:plate/insurance:', error);
    res.status(500).json({ success: false, message: 'Error al obtener seguros', error: error.message });
  }
});

/**
 * @route   POST /api/buses/:plate/insurance
 * @desc    Registrar nueva póliza
 * @access  Admin
 * @body    { id_insurance, id_insurance_type, id_insurer, start_date_insu, end_date_insu, doc_url? }
 */
router.post('/:plate/insurance', requirePermission(PERMISSIONS.EDIT_BUSES), async (req, res) => {
  try {
    const result = await busesService.addBusInsurance(req.params.plate, req.body, req.user.id_user);
    if (!result.success) {
      const status = result.error_code === 'BUS_NOT_FOUND' ? 404 : 400;
      return res.status(status).json(result);
    }
    res.status(201).json(result);
  } catch (error) {
    console.error('Error en POST /buses/:plate/insurance:', error);
    res.status(500).json({ success: false, message: 'Error al registrar póliza', error: error.message });
  }
});

/**
 * @route   PATCH /api/buses/:plate/insurance/:type/doc
 * @desc    Actualizar URL del documento de una póliza (clave: plate + tipo)
 * @access  Admin
 * @body    { doc_url: string }
 */
router.patch('/:plate/insurance/:type/doc', requirePermission(PERMISSIONS.EDIT_BUSES), async (req, res) => {
  try {
    const { doc_url } = req.body;
    if (!doc_url) return res.status(400).json({ success: false, message: 'doc_url es requerido' });
    const result = await busesService.updateInsuranceDocUrl(req.params.plate, req.params.type, doc_url, req.user.id_user);
    if (!result.success) {
      const status = result.error_code === 'BUS_NOT_FOUND' ? 404 : 400;
      return res.status(status).json(result);
    }
    res.json(result);
  } catch (error) {
    console.error('Error en PATCH /buses/:plate/insurance/:type/doc:', error);
    res.status(500).json({ success: false, message: 'Error al actualizar documento', error: error.message });
  }
});

// ─── Documentos de tránsito por bus ──────────────────────────────────────────

/**
 * @route   GET /api/buses/:plate/transit-docs
 * @desc    Listar documentos de tránsito de un bus
 */
router.get('/:plate/transit-docs', requirePermission(PERMISSIONS.VIEW_BUSES), async (req, res) => {
  try {
    const result = await busesService.getBusTransitDocs(req.params.plate);
    if (!result.success) {
      const status = result.error_code === 'BUS_NOT_FOUND' ? 404 : 400;
      return res.status(status).json(result);
    }
    res.json(result);
  } catch (error) {
    console.error('Error en GET /buses/:plate/transit-docs:', error);
    res.status(500).json({ success: false, message: 'Error al obtener documentos', error: error.message });
  }
});

/**
 * @route   POST /api/buses/:plate/transit-docs
 * @desc    Registrar nuevo documento de tránsito
 * @access  Admin
 * @body    { id_doc, doc_number, init_date, end_date, doc_url? }
 */
router.post('/:plate/transit-docs', requirePermission(PERMISSIONS.EDIT_BUSES), async (req, res) => {
  try {
    const result = await busesService.addBusTransitDoc(req.params.plate, req.body, req.user.id_user);
    if (!result.success) {
      const status = result.error_code === 'BUS_NOT_FOUND' ? 404 : 400;
      return res.status(status).json(result);
    }
    res.status(201).json(result);
  } catch (error) {
    console.error('Error en POST /buses/:plate/transit-docs:', error);
    res.status(500).json({ success: false, message: 'Error al registrar documento', error: error.message });
  }
});

/**
 * @route   PATCH /api/buses/:plate/transit-docs/:id_doc/doc
 * @desc    Actualizar URL del documento de tránsito (clave: plate + tipo)
 * @access  Admin
 * @body    { doc_url: string }
 */
router.patch('/:plate/transit-docs/:id_doc/doc', requirePermission(PERMISSIONS.EDIT_BUSES), async (req, res) => {
  try {
    const { plate, id_doc } = req.params;
    const { doc_url } = req.body;
    if (!doc_url) return res.status(400).json({ success: false, message: 'doc_url es requerido' });
    const result = await busesService.updateTransitDocUrl(plate, id_doc, doc_url, req.user.id_user);
    if (!result.success) {
      const status = result.error_code === 'BUS_NOT_FOUND' ? 404 : 400;
      return res.status(status).json(result);
    }
    res.json(result);
  } catch (error) {
    console.error('Error en PATCH /buses/:plate/transit-docs/:id_doc/doc:', error);
    res.status(500).json({ success: false, message: 'Error al actualizar documento', error: error.message });
  }
});

export default router;
