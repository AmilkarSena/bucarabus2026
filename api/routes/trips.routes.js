/**
 * @fileoverview Rutas para endpoints de viajes
 * Arquitectura: Router → Controller → Service → Database Function
 */

import express from 'express';
import * as tripsController from '../controllers/trips.controller.js';
import { verifyToken } from '../middlewares/auth.middleware.js';

const router = express.Router();

/**
 * POST /api/trips
 * Crear un viaje individual
 * Body: { id_route, id_driver, id_bus, departure_epoch }
 */
router.post('/', verifyToken, tripsController.createTrip);

/**
 * POST /api/trips/batch
 * Crear múltiples viajes en lote
 * Body: { trips: [{ id_route, id_driver, id_bus, departure_epoch }, ...] }
 */
router.post('/batch', verifyToken, tripsController.createTripsBatch);

/**
 * GET /api/trips
 * Listar viajes con filtros opcionales
 * Query params: status_trip, id_route, id_driver, id_bus, from_epoch, to_epoch, limit, offset
 * Ejemplo: GET /api/trips?status_trip=3&id_route=5&limit=50&offset=0
 */
router.get('/', verifyToken, tripsController.listTrips);

/**
 * GET /api/trips/:id_trip
 * Obtener un viaje por su ID
 */
router.get('/:id_trip', verifyToken, tripsController.getTripById);

/**
 * GET /api/trips/:id_trip/events
 * Obtener historial de eventos de un viaje
 */
router.get('/:id_trip/events', verifyToken, tripsController.getTripEvents);

/**
 * PUT /api/trips/:id_trip
 * Actualizar un viaje existente
 * Body: { start_time?, end_time?, plate_number?, status_trip? }
 */
router.put('/:id_trip', verifyToken, tripsController.updateTrip);

/**
 * DELETE /api/trips/:id_trip
 * Cancela un viaje individual (soft delete: status_trip=5, is_active=FALSE)
 * Body: { cancellation_reason?: string, force_cancel?: boolean }
 * - force_cancel: requerido TRUE para cancelar viajes activos (status_trip=3)
 * - cancellation_reason: obligatorio si force_cancel=TRUE (mínimo 10 caracteres)
 */
router.delete('/:id_trip', verifyToken, tripsController.cancelTrip);

/**
 * DELETE /api/trips/batch
 * Cancela múltiples viajes de una ruta en una fecha específica
 * Body: { id_route: number, trip_date: string, cancellation_reason?: string, force_cancel_active?: boolean }
 * - force_cancel_active: si TRUE, cancela también viajes activos; si FALSE, los omite
 * - cancellation_reason: obligatorio si force_cancel_active=TRUE
 */
router.delete('/batch', verifyToken, tripsController.cancelTripsBatch);

export default router;
