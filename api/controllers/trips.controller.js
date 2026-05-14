/**
 * @fileoverview Controlador para endpoints de viajes
 * Maneja validación de req/res y delega lógica al servicio
 */

import * as tripsService from '../services/trips.service.js';
// Estados válidos: 1=pendiente, 2=asignado, 3=activo, 4=completado, 5=cancelado (ver tab_trip_statuses)
const isValidStatus = (status) => Number.isInteger(status) && status >= 1 && status <= 5;

/**
 * POST /api/trips
 * Crea un viaje individual
 */
async function createTrip(req, res) {
  try {
    const { id_route, trip_date, start_time, end_time, plate_number, id_driver, status_trip } = req.body;

    // Validar parámetros requeridos
    if (!id_route || !trip_date || !start_time || !end_time) {
      return res.status(400).json({
        success: false,
        msg: 'Faltan parámetros requeridos: id_route, trip_date, start_time, end_time'
      });
    }

    // Validar formato de tiempo (HH:MM o HH:MM:SS)
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/;
    if (!timeRegex.test(start_time) || !timeRegex.test(end_time)) {
      return res.status(400).json({
        success: false,
        msg: 'El formato de hora debe ser HH:MM o HH:MM:SS válido',
        error_code: 'INVALID_TIME_FORMAT'
      });
    }

    // Validar que la fecha no sea pasada
    // Ajuste para zona horaria: restamos 5 horas al server (Colombia) para la comparación
    const today = new Date(new Date().getTime() - (5 * 60 * 60 * 1000));
    today.setHours(0, 0, 0, 0);
    const requestedDate = new Date(trip_date + 'T00:00:00');
    if (requestedDate < today) {
      return res.status(400).json({
        success: false,
        msg: 'No se pueden crear viajes en fechas pasadas (Hora Colombia)',
        error_code: 'PAST_DATE'
      });
    }

    // Obtener user_create desde el token JWT (si está autenticado)
    // Por ahora usamos -1 (sistema) si no hay usuario autenticado
    const user_create = req.user?.id_user || -1;

    const tripData = {
      id_route,
      trip_date,
      start_time,
      end_time,
      user_create,
      plate_number: plate_number || null,
      id_driver: id_driver || null,
      status_trip: status_trip || 1  // 1 = pendiente (ver tab_trip_statuses)
    };

    const result = await tripsService.createTrip(tripData);

    if (result.success) {
      // 🔔 Notificar a todos los clientes enviando el viaje creado
      if (req.app.get('io')) {
        req.app.get('io').emit('trip-updated', result.data);
      }
      return res.status(201).json(result);
    } else {
      // Mapear códigos de error a status HTTP
      const statusCode = getHttpStatusForError(result.error_code);
      return res.status(statusCode).json(result);
    }
  } catch (error) {
    console.error('Error en createTrip controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor',
      error_code: 'INTERNAL_ERROR'
    });
  }
}

/**
 * POST /api/trips/batch
 * Crea múltiples viajes en lote
 */
async function createTripsBatch(req, res) {
  try {
    const { id_route, trip_date, trips } = req.body;

    // Validar parámetros globales
    if (!id_route || !trip_date) {
      return res.status(400).json({
        success: false,
        msg: 'Faltan parámetros requeridos: id_route, trip_date'
      });
    }

    // Validar que la fecha no sea pasada
    // Ajuste para zona horaria: restamos 5 horas al server (Colombia) para la comparación
    const today = new Date(new Date().getTime() - (5 * 60 * 60 * 1000));
    today.setHours(0, 0, 0, 0);
    const requestedDate = new Date(trip_date + 'T00:00:00');
    if (requestedDate < today) {
      return res.status(400).json({
        success: false,
        msg: 'No se pueden crear viajes en fechas pasadas (Hora Colombia)',
        error_code: 'PAST_DATE'
      });
    }

    // Validar que trips sea un array
    if (!Array.isArray(trips) || trips.length === 0) {
      return res.status(400).json({
        success: false,
        msg: 'El campo "trips" debe ser un array no vacío'
      });
    }

    // Validar estructura de cada viaje
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/;
    for (let i = 0; i < trips.length; i++) {
      const trip = trips[i];
      if (!trip.start_time || !trip.end_time) {
        return res.status(400).json({
          success: false,
          msg: `Viaje en posición ${i} requiere start_time y end_time`
        });
      }
      if (!timeRegex.test(trip.start_time) || !timeRegex.test(trip.end_time)) {
        return res.status(400).json({
          success: false,
          msg: `Viaje en posición ${i} tiene un formato de hora inválido (debe ser HH:MM o HH:MM:SS)`,
          error_code: 'INVALID_TIME_FORMAT'
        });
      }
    }

    const user_create = req.user?.id_user || -1;

    const batchData = {
      id_route,
      trip_date,
      trips,
      user_create
    };

    const result = await tripsService.createTripsInBatch(batchData);

    if (result.success) {
      // 🔔 Notificar recarga del batch
      if (req.app.get('io')) {
        req.app.get('io').emit('trips-batch-updated', { id_route, trip_date });
      }
      return res.status(201).json(result);
    } else {
      const statusCode = getHttpStatusForError(result.error_code);
      return res.status(statusCode).json(result);
    }
  } catch (error) {
    console.error('Error en createTripsBatch controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor',
      error_code: 'INTERNAL_ERROR'
    });
  }
}

/**
 * GET /api/trips/:id_trip
 * Obtiene un viaje por su ID
 */
async function getTripById(req, res) {
  try {
    const id_trip = parseInt(req.params.id_trip, 10);

    if (isNaN(id_trip)) {
      return res.status(400).json({
        success: false,
        msg: 'ID de viaje inválido'
      });
    }

    const trip = await tripsService.getTripById(id_trip);

    if (!trip) {
      return res.status(404).json({
        success: false,
        msg: `Viaje con ID ${id_trip} no encontrado`
      });
    }

    return res.status(200).json({
      success: true,
      data: trip
    });
  } catch (error) {
    console.error('Error en getTripById controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor'
    });
  }
}

/**
 * GET /api/trips
 * Lista viajes con filtros opcionales
 * Query params: status_trip, id_route, id_driver, id_bus, from_epoch, to_epoch, limit, offset
 */
async function listTrips(req, res) {
  try {
    const {
      status_trip,
      id_route,
      id_driver,
      id_bus,
      plate_number,
      trip_date,
      from_epoch,
      to_epoch,
      limit = 100,
      offset = 0
    } = req.query;

    // Construir objeto de filtros
    const filters = {};

    if (status_trip !== undefined) {
      const statusNum = parseInt(status_trip, 10);
      if (!isValidStatus(statusNum)) {
        return res.status(400).json({
          success: false,
          msg: 'Estado inválido. Valores válidos: 1=pendiente, 2=asignado, 3=activo, 4=completado, 5=cancelado'
        });
      }
      filters.status_trip = statusNum;
    }

    if (id_route) filters.id_route = parseInt(id_route, 10);
    if (id_driver) filters.id_driver = parseInt(id_driver, 10);
    if (id_bus) filters.id_bus = parseInt(id_bus, 10);
    if (plate_number) filters.plate_number = plate_number;     // filtro por placa
    if (from_epoch) filters.from_epoch = parseInt(from_epoch, 10);
    if (to_epoch) filters.to_epoch = parseInt(to_epoch, 10);

    // Filtro por fecha exacta (YYYY-MM-DD)
    if (trip_date) filters.trip_date = trip_date;

    filters.limit = Math.min(parseInt(limit, 10) || 100, 500); // Máximo 500
    filters.offset = parseInt(offset, 10) || 0;

    const trips = await tripsService.listTrips(filters);
    const total = await tripsService.countTrips(filters);

    return res.status(200).json({
      success: true,
      data: trips,
      pagination: {
        total,
        limit: filters.limit,
        offset: filters.offset,
        has_more: filters.offset + trips.length < total
      }
    });
  } catch (error) {
    console.error('Error en listTrips controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor'
    });
  }
}

/**
 * GET /api/trips/:id_trip/events
 * Obtiene el historial de eventos de un viaje
 */
async function getTripEvents(req, res) {
  try {
    const id_trip = parseInt(req.params.id_trip, 10);

    if (isNaN(id_trip)) {
      return res.status(400).json({
        success: false,
        msg: 'ID de viaje inválido'
      });
    }

    const events = await tripsService.getTripEvents(id_trip);

    return res.status(200).json({
      success: true,
      data: events
    });
  } catch (error) {
    console.error('Error en getTripEvents controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor'
    });
  }
}

/**
 * Mapea códigos de error de la DB a códigos HTTP apropiados
 * @param {string} errorCode - Código de error de la función de DB
 * @returns {number} - Código de estado HTTP
 */
function getHttpStatusForError(errorCode) {
  const errorMap = {
    'MISSING_PARAMS': 400,
    'INVALID_INPUT': 400,
    'ROUTE_NOT_FOUND': 404,
    'DRIVER_NOT_FOUND': 404,
    'BUS_NOT_FOUND': 404,
    'USER_NOT_FOUND': 404,
    'TRIP_NOT_FOUND': 404,
    'USER_CANCEL_NOT_FOUND': 404,
    'DUPLICATE_TRIP': 409,
    'CONFLICT': 409,
    'TRIP_ALREADY_CANCELLED': 409,
    'CANCELLATION_REASON_REQUIRED': 400,
    'FORCE_CANCEL_REQUIRED': 403,
    'TRIP_UPDATE_FAILED': 500,
    'TRIP_UPDATE_FK_VIOLATION': 400,
    'TRIP_UPDATE_CHECK_VIOLATION': 400,
    'TRIP_UPDATE_ERROR': 500,
    'INVALID_STATUS_TRANSITION': 409,
    'STATUS_INVALID': 400,
    'STATUS_INCONSISTENT_WITH_BUS': 400,
    'STATUS_MUST_BE_PENDING': 400,
    'NO_CHANGES': 400,
    'ROUTE_ID_NULL': 400,
    'TRIP_DATE_NULL': 400,
    'DB_ERROR': 500,
    'INTERNAL_ERROR': 500
  };

  return errorMap[errorCode] || 500;
}

/**
 * PUT /api/trips/:id_trip
 * Actualiza un viaje existente
 */
async function updateTrip(req, res) {
  try {
    const id_trip = parseInt(req.params.id_trip, 10);

    if (isNaN(id_trip)) {
      return res.status(400).json({
        success: false,
        msg: 'ID de viaje inválido'
      });
    }

    const { id_route, trip_date, start_time, end_time, id_bus, id_driver, id_status } = req.body;

    // Obtener usuario desde JWT
    const user_update = req.user?.id_user || -1;

    const updateData = {
      id_route:   id_route   !== undefined ? id_route   : null,
      trip_date:  trip_date  !== undefined ? trip_date  : null,
      start_time: start_time !== undefined ? start_time : null,
      end_time:   end_time   !== undefined ? end_time   : null,
      id_bus:     id_bus     !== undefined ? id_bus     : null,  // 0 = desasignar
      id_driver:  id_driver  !== undefined ? id_driver  : null,  // 0 = desasignar
      id_status:  id_status  !== undefined ? id_status  : null,
      user_update
    };

    // Validar formato de tiempo (HH:MM o HH:MM:SS) si se proporcionan
    const timeRegex = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$/;
    if (updateData.start_time && !timeRegex.test(updateData.start_time)) {
      return res.status(400).json({ success: false, msg: 'Formato de start_time inválido', error_code: 'INVALID_TIME_FORMAT' });
    }
    if (updateData.end_time && !timeRegex.test(updateData.end_time)) {
      return res.status(400).json({ success: false, msg: 'Formato de end_time inválido', error_code: 'INVALID_TIME_FORMAT' });
    }

    const result = await tripsService.updateTrip(id_trip, updateData);

    if (result.success) {
      // 🔔 Notificar el viaje actualizado
      if (req.app.get('io')) {
        req.app.get('io').emit('trip-updated', result.data);
      }
      return res.status(200).json(result);
    } else {
      const statusCode = getHttpStatusForError(result.error_code);
      return res.status(statusCode).json(result);
    }
  } catch (error) {
    console.error('Error en updateTrip controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor',
      error_code: 'INTERNAL_ERROR'
    });
  }
}

/**
 * DELETE /api/trips/:id_trip
 * Cancela un viaje individual (soft delete)
 */
async function cancelTrip(req, res) {
  try {
    const id_trip = parseInt(req.params.id_trip, 10);

    if (isNaN(id_trip)) {
      return res.status(400).json({
        success: false,
        msg: 'ID de viaje inválido'
      });
    }

    const { cancellation_reason, force_cancel } = req.body;

    // Obtener usuario desde JWT o usar -1 (sistema)
    const user_cancel = req.user?.id_user || -1;

    // Validación: Si force_cancel es true, debe haber un cancellation_reason
    if (force_cancel && (!cancellation_reason || cancellation_reason.trim().length < 10)) {
      return res.status(400).json({
        success: false,
        msg: 'La razón de cancelación es obligatoria para viajes activos (mínimo 10 caracteres)',
        error_code: 'CANCELLATION_REASON_REQUIRED'
      });
    }

    const result = await tripsService.cancelTrip(
      id_trip,
      user_cancel,
      cancellation_reason || null,
      force_cancel || false
    );

    if (result.success) {
      // 🔔 Notificar eliminación (soft delete)
      if (req.app.get('io')) {
        req.app.get('io').emit('trip-deleted', { id_trip });
      }
      return res.status(200).json(result);
    } else {
      const statusCode = getHttpStatusForError(result.error_code);
      return res.status(statusCode).json(result);
    }
  } catch (error) {
    console.error('Error en cancelTrip controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor',
      error_code: 'INTERNAL_ERROR'
    });
  }
}

/**
 * DELETE /api/trips/batch
 * Cancela múltiples viajes de una ruta en una fecha (batch)
 */
async function cancelTripsBatch(req, res) {
  try {
    const { id_route, trip_date, cancellation_reason, force_cancel_active } = req.body;

    // Validar parámetros requeridos
    if (!id_route || !trip_date) {
      return res.status(400).json({
        success: false,
        msg: 'Faltan parámetros requeridos: id_route, trip_date'
      });
    }

    // Obtener usuario desde JWT
    const user_cancel = req.user?.id_user || -1;

    // Validación: Si force_cancel_active es true, debe haber un cancellation_reason
    if (force_cancel_active && (!cancellation_reason || cancellation_reason.trim().length < 10)) {
      return res.status(400).json({
        success: false,
        msg: 'La razón de cancelación es obligatoria al forzar cancelación de viajes activos (mínimo 10 caracteres)',
        error_code: 'CANCELLATION_REASON_REQUIRED'
      });
    }

    const result = await tripsService.cancelTripsBatch(
      id_route,
      trip_date,
      user_cancel,
      cancellation_reason || null,
      force_cancel_active || false
    );

    if (result.success) {
      // 🔔 Notificar recarga del batch
      if (req.app.get('io')) {
        req.app.get('io').emit('trips-batch-updated', { id_route, trip_date });
      }
      return res.status(200).json(result);
    } else {
      const statusCode = getHttpStatusForError(result.error_code);
      return res.status(statusCode).json(result);
    }
  } catch (error) {
    console.error('Error en cancelTripsBatch controller:', error);
    return res.status(500).json({
      success: false,
      msg: 'Error interno del servidor',
      error_code: 'INTERNAL_ERROR'
    });
  }
}

export {
  createTrip,
  createTripsBatch,
  getTripById,
  listTrips,
  getTripEvents,
  updateTrip,
  cancelTrip,
  cancelTripsBatch
};
