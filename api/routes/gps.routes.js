import express from 'express';
import * as gpsService from '../services/gps.service.js';
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js';
import { PERMISSIONS } from '../config/constants.js';

const router = express.Router();

/**
 * POST /api/gps/snapshot
 * Guardar snapshot GPS (cada 10 minutos desde app conductor)
 */
router.post('/snapshot', verifyToken, async (req, res) => {
    try {
        const { id_trip, lat, lng, speed } = req.body;
        
        if (!id_trip || !lat || !lng) {
            return res.status(400).json({
                success: false,
                error: 'Se requiere id_trip, lat y lng'
            });
        }
        
        const snapshot = await gpsService.saveGPSSnapshot({
            id_trip,
            lat,
            lng,
            speed
        });
        
        res.status(201).json({
            success: true,
            data: snapshot,
            message: 'Snapshot GPS guardado'
        });
    } catch (error) {
        console.error('Error guardando snapshot GPS:', error);
        res.status(500).json({
            success: false,
            error: 'Error al guardar snapshot GPS',
            message: error.message
        });
    }
});

/**
 * GET /api/gps/trip/:id_trip
 * Obtener histórico GPS completo de un viaje
 */
router.get('/trip/:id_trip', verifyToken, async (req, res) => {
    try {
        const history = await gpsService.getTripGPSHistory(req.params.id_trip);
        res.json({
            success: true,
            data: history,
            count: history.length
        });
    } catch (error) {
        console.error('Error obteniendo histórico GPS:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener histórico GPS',
            message: error.message
        });
    }
});

/**
 * GET /api/gps/trip/:id_trip/last
 * Obtener último snapshot GPS de un viaje
 */
router.get('/trip/:id_trip/last', verifyToken, async (req, res) => {
    try {
        const snapshot = await gpsService.getLastGPSSnapshot(req.params.id_trip);
        
        if (!snapshot) {
            return res.status(404).json({
                success: false,
                error: 'No se encontró histórico GPS para este viaje'
            });
        }
        
        res.json({
            success: true,
            data: snapshot
        });
    } catch (error) {
        console.error('Error obteniendo último snapshot:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener último snapshot',
            message: error.message
        });
    }
});

/**
 * GET /api/gps/date/:date
 * Obtener histórico GPS de todos los viajes de una fecha
 */
router.get('/date/:date', verifyToken, async (req, res) => {
    try {
        const history = await gpsService.getGPSHistoryByDate(req.params.date);
        res.json({
            success: true,
            data: history,
            count: history.length
        });
    } catch (error) {
        console.error('Error obteniendo histórico por fecha:', error);
        res.status(500).json({
            success: false,
            error: 'Error al obtener histórico por fecha',
            message: error.message
        });
    }
});

/**
 * GET /api/gps/trip/:id_trip/statistics
 * Obtener estadísticas calculadas desde el histórico GPS
 */
router.get('/trip/:id_trip/statistics', verifyToken, async (req, res) => {
    try {
        const stats = await gpsService.getTripStatistics(req.params.id_trip);
        res.json({
            success: true,
            data: stats
        });
    } catch (error) {
        console.error('Error calculando estadísticas:', error);
        res.status(500).json({
            success: false,
            error: 'Error al calcular estadísticas',
            message: error.message
        });
    }
});

/**
 * DELETE /api/gps/cleanup
 * Limpiar registros antiguos (admin)
 */
router.delete('/cleanup', requirePermission(PERMISSIONS.MODULE_SETTINGS), async (req, res) => {
    try {
        const { days = 90 } = req.query;
        const result = await gpsService.cleanupOldGPSHistory(parseInt(days));
        
        res.json({
            success: true,
            message: `Registros eliminados: ${result.deleted_count}`,
            data: result
        });
    } catch (error) {
        console.error('Error limpiando histórico:', error);
        res.status(500).json({
            success: false,
            error: 'Error al limpiar histórico',
            message: error.message
        });
    }
});

export default router;
