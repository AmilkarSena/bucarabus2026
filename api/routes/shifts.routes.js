import express from 'express';
import * as shiftsService from '../services/shifts.service.js';
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js';
import { PERMISSIONS } from '../config/constants.js';

const router = express.Router();

/**
 * GET /api/shifts
 * Obtener todos los turnos activos (público — lo consulta la app pasajeros sin auth)
 */
router.get('/', async (req, res) => {
    try {
        const shifts = await shiftsService.getActiveShifts();
        res.json({
            success: true,
            data: shifts,
            count: shifts.length,
            currentTime: new Date().toISOString(),
            localTime: new Date().toLocaleString('es-CO', { timeZone: 'America/Bogota' })
        });
    } catch (error) {
        console.error('Error al obtener turnos activos:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener turnos activos',
            message: error.message
        });
    }
});

/**
 * GET /api/shifts/debug/all
 * [DEBUG] Obtener TODOS los viajes de hoy sin filtro horario
 */
router.get('/debug/all', requirePermission(PERMISSIONS.MANAGE_USERS), async (req, res) => {                                         // Endpoint de debug para obtener TODOS los viajes de hoy sin filtro horario, útil para verificar que la lógica de turnos no esté omitiendo viajes por error en horarios o estados
    try {                                
        const trips = await shiftsService.getAllTodayTrips();                          // Lógica sin filtro horario ni de estado, para debug y ver si hay viajes que deberían estar en turnos pero no aparecen por algún error en la lógica de horarios o estados
        res.json({                                                                   // Respuesta con formato consistente, incluyendo timestamps para debug
            success: true,                                                          // Indicador de éxito
            data: trips,                                                           // Datos de los viajes                                               
            count: trips.length,                                                  // Conteo de viajes para ver si coincide con lo esperado
            serverTime: new Date().toISOString(),
            localTime: new Date().toLocaleString('es-CO', { timeZone: 'America/Bogota' }) // Hora local para verificar que los horarios se estén interpretando correctamente en la zona horaria de Colombia
        });
    } catch (error) {
        console.error('Error en debug:', error);
        res.status(500).json({ success: false, error: error.message });
    }
});

/**
 * GET /api/shifts/available-buses
 * Obtener buses disponibles (sin turno activo)
 */
router.get('/available-buses', verifyToken, async (req, res) => {                            // Endpoint para obtener buses disponibles, es decir, aquellos que no tienen un turno activo en el día actual. Esto se determina verificando que no tengan un viaje con estado "Asignado" o "En progreso" para hoy.
    try {
        const buses = await shiftsService.getAvailableBuses();                  // Lógica para obtener buses disponibles, que no tengan un viaje activo (estado 1 o 2) para hoy. Esto se hace con una consulta SQL que filtra los buses por placa y verifica que no estén en la lista de viajes activos para hoy.
        res.json({
            success: true,
            data: buses,
            count: buses.length
        });
    } catch (error) {
        console.error('Error al obtener buses disponibles:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener buses disponibles',
            message: error.message
        });
    }
});

/**
 * GET /api/shifts/:plateNumber
 * Obtener turno activo por placa
 */
router.get('/:plateNumber', verifyToken, async (req, res) => {
    try {
        const shift = await shiftsService.getActiveShiftByPlate(req.params.plateNumber);
        if (!shift) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró turno activo para este bus'
            });
        }
        res.json({
            success: true,
            data: shift
        });
    } catch (error) {
        console.error('Error al obtener turno:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener turno',
            message: error.message
        });
    }
});

/**
 * POST /api/shifts
 * Iniciar un nuevo turno
 */
router.post('/', verifyToken, async (req, res) => {
    try {
        const { plate_number, id_route } = req.body;
        
        if (!plate_number || !id_route) {
            return res.status(400).json({
                success: false,
                error: 'Se requiere plate_number e id_route'
            });
        }
        
        const shift = await shiftsService.startShift({ plate_number, id_route });
        res.status(201).json({
            success: true,
            data: shift,
            message: 'Turno iniciado exitosamente'
        });
    } catch (error) {
        console.error('Error al iniciar turno:', error);
        res.status(500).json({
            success: false,
            error: 'Error al iniciar turno',
            message: error.message
        });
    }
});

/**
 * PUT /api/shifts/:plateNumber/progress
 * Actualizar progreso del turno
 */
router.put('/:plateNumber/progress', (req, res, next) => {
    if (req.body.simulated) return next();
    verifyToken(req, res, next);
}, async (req, res) => {
    try {
        const { progress, trips_completed } = req.body;
        
        const shift = await shiftsService.updateProgress(
            req.params.plateNumber, 
            progress, 
            trips_completed
        );
        
        if (!shift) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró turno activo para este bus'
            });
        }
        
        res.json({
            success: true,
            data: shift
        });
    } catch (error) {
        console.error('Error al actualizar progreso:', error);
        res.status(500).json({
            success: false,
            error: 'Error al actualizar progreso',
            message: error.message
        });
    }
});

/**
 * DELETE /api/shifts/:plateNumber
 * Finalizar turno
 */
router.delete('/:plateNumber', verifyToken, async (req, res) => {
    try {
        const shift = await shiftsService.endShift(req.params.plateNumber);
        if (!shift) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró turno activo para este bus'
            });
        }
        res.json({
            success: true,
            data: shift,
            message: 'Turno finalizado exitosamente'
        });
    } catch (error) {
        console.error('Error al finalizar turno:', error);
        res.status(500).json({
            success: false,
            error: 'Error al finalizar turno',
            message: error.message
        });
    }
});

export default router;
