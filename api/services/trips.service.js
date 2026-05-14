/**
 * @fileoverview Servicio para gestión de viajes
 * Interactúa ÚNICAMENTE con stored functions, NO con tablas directamente
 * 
 * Seguridad: El usuario de DB tiene GRANT EXECUTE en funciones, NO acceso directo a tablas
 */

import pool from '../config/database.js';
// Estados válidos: 1=pendiente, 2=asignado, 3=activo, 4=completado, 5=cancelado (ver tab_trip_statuses)
const isValidStatus = (status) => Number.isInteger(status) && status >= 1 && status <= 5;

/**
 * Crea un viaje individual
 * @param {Object} tripData - Datos del viaje
 * @param {number} tripData.id_route - ID de la ruta
 * @param {string} tripData.trip_date - Fecha del viaje (YYYY-MM-DD)
 * @param {string} tripData.start_time - Hora de inicio (HH:mm:ss)
 * @param {string} tripData.end_time - Hora de fin (HH:mm:ss)
 * @param {number} tripData.user_create - ID del usuario que crea (-1 para sistema)
 * @param {string} [tripData.plate_number] - Placa del bus (opcional)
 * @param {number} [tripData.id_driver] - Cédula del conductor (opcional)
 * @param {number} [tripData.status_trip=1] - Estado del viaje (1=pendiente, ver tab_trip_statuses)
 * @returns {Promise<Object>} - Resultado de la operación
 */
async function createTrip(tripData) {
  const {
    id_route,
    trip_date,
    start_time,
    end_time,
    user_create = 1,
    id_bus = null,      // ID interno del bus (tab_buses.id_bus)
    id_driver = null,   // Cédula del conductor (tab_drivers.id_driver)
    status_trip = 1     // 1 = pendiente (ver tab_trip_statuses)
  } = tripData;

  // Validación básica de parámetros requeridos
  if (!id_route || !trip_date || !start_time || !end_time) {
    return {
      success: false,
      msg: 'Faltan parámetros requeridos: id_route, trip_date, start_time, end_time',
      error_code: 'MISSING_PARAMS'
    };
  }

  try {
    const query = `
      SELECT success, msg, error_code, out_id_trip FROM fun_create_trip(
        $1::SMALLINT,   -- wid_route
        $2::DATE,       -- wtrip_date
        $3::TIME,       -- wstart_time
        $4::TIME,       -- wend_time
        $5::SMALLINT,   -- wuser_create
        $6::SMALLINT,   -- wid_bus
        $7::BIGINT,     -- wid_driver
        $8::SMALLINT    -- wid_status
      );
    `;

    const values = [id_route, trip_date, start_time, end_time, user_create, id_bus, id_driver, status_trip];
    const result = await pool.query(query, values);

    const response = result.rows[0];

    return response;
  } catch (error) {
    console.error('Error en createTrip:', error);
    return {
      success: false,
      msg: `Error al crear viaje: ${error.message}`,
      error_code: 'DB_ERROR'
    };
  }
}

/**
 * Crea múltiples viajes en lote
 * @param {Object} batchData - Datos del batch
 * @param {number} batchData.id_route - ID de la ruta
 * @param {string} batchData.trip_date - Fecha de los viajes (YYYY-MM-DD)
 * @param {Array} batchData.trips - Array de viajes [{start_time, end_time, plate_number?, id_driver?, status_trip?}]
 * @param {number} batchData.user_create - ID del usuario que crea (-1 para sistema)
 * @returns {Promise<Object>} - Resultado con viajes creados y fallidos
 */
async function createTripsInBatch(batchData) {
  const { id_route, trip_date, trips, user_create = -1 } = batchData;

  // Validación básica
  if (!id_route || !trip_date || !Array.isArray(trips) || trips.length === 0) {
    return {
      success: false,
      msg: 'Faltan parámetros requeridos: id_route, trip_date, trips (array)',
      error_code: 'INVALID_INPUT'
    };
  }

  try {
    // Formatear el array de trips como JSON para PostgreSQL
    const tripsJson = JSON.stringify(trips);

    // Llamar a la stored function fun_create_trips_batch
    const query = `
      SELECT success, msg, error_code, trips_created, trips_failed, trip_ids FROM fun_create_trips_batch(
        $1::SMALLINT,  -- wid_route
        $2::DATE,      -- wtrip_date
        $3::JSONB,     -- wtrips
        $4::SMALLINT   -- wuser_create
      );
    `;

    const values = [id_route, trip_date, tripsJson, user_create];
    const result = await pool.query(query, values);

    // La función retorna columnas OUT directamente, no un JSON anidado
    const response = result.rows[0];

    return response;
  } catch (error) {
    console.error('Error en createTripsInBatch:', error);
    return {
      success: false,
      msg: `Error al crear viajes en lote: ${error.message}`,
      error_code: 'DB_ERROR'
    };
  }
}

/**
 * Obtiene un viaje por su ID
 * @param {number} idTrip - ID del viaje
 * @returns {Promise<Object|null>} - Datos del viaje o null si no existe
 */
async function getTripById(idTrip) {
  try {
    const query = `
      SELECT 
        t.id_trip,
        t.id_route,
        t.trip_date,
        t.start_time,
        t.end_time,
        t.id_bus,
        b.plate_number,
        t.id_driver,
        t.id_status AS status_trip,
        t.started_at,
        t.completed_at,
        ts.status_name,
        ts.color_hex,
        t.created_at,
        t.user_create,
        t.updated_at,
        t.user_update,
        t.is_active,
        -- Datos relacionados
        r.name_route,
        r.color_route,
        d.name_driver,
        b.amb_code as bus_code,
        b.capacity_bus AS bus_capacity
      FROM tab_trips t
      LEFT JOIN tab_trip_statuses ts ON t.id_status = ts.id_status
      LEFT JOIN tab_routes r ON t.id_route = r.id_route
      LEFT JOIN tab_drivers d ON t.id_driver = d.id_driver
      LEFT JOIN tab_buses b ON t.id_bus = b.id_bus
      WHERE t.id_trip = $1
        AND t.is_active = TRUE;
    `;

    const result = await pool.query(query, [idTrip]);

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  } catch (error) {
    console.error('Error en getTripById:', error);
    throw error;
  }
}

/**
 * Lista viajes con filtros opcionales
 * @param {Object} filters - Filtros de búsqueda
 * @param {number} [filters.status_trip] - Filtrar por estado (1-5)
 * @param {number} [filters.id_route] - Filtrar por ruta
 * @param {number} [filters.id_driver] - Filtrar por conductor
 * @param {number} [filters.id_bus] - Filtrar por bus
 * @param {number} [filters.from_epoch] - Timestamp desde
 * @param {number} [filters.to_epoch] - Timestamp hasta
 * @param {number} [filters.limit=100] - Límite de resultados
 * @param {number} [filters.offset=0] - Offset para paginación
 * @returns {Promise<Array>} - Array de viajes
 */
async function listTrips(filters = {}) {
  const {
    status_trip,
    id_route,
    id_driver,
    plate_number,   // filtro por placa
    trip_date,      // filtro por fecha exacta (YYYY-MM-DD)
    from_epoch,     // Se convertirá a fecha/hora
    to_epoch,       // Se convertirá a fecha/hora
    limit = 100,
    offset = 0
  } = filters;

  // Si se consulta hoy, activar y finalizar viajes por horario (lazy evaluation)
  // Ajuste para zona horaria de Colombia (UTC-5)
  const colDate = new Date(new Date().getTime() - (5 * 60 * 60 * 1000));
  const todayStr = colDate.toISOString().split('T')[0];
  const localTime = colDate.toISOString().split('T')[1].substring(0, 8);

  if (!trip_date || trip_date === todayStr) {
    await pool.query('SELECT fun_auto_activate_trips($1::DATE, $2::TIME)', [todayStr, localTime]);
    await pool.query('SELECT fun_finalize_expired_trips($1::DATE, $2::TIME)', [todayStr, localTime]);
  }

  try {
    // Construir query dinámicamente según filtros
    let query = `
      SELECT 
        t.id_trip,
        t.id_route,
        t.trip_date,
        t.start_time,
        t.end_time,
        t.id_bus,
        b.plate_number,
        t.id_driver,
        t.id_status AS status_trip,
        t.started_at,
        t.completed_at,
        ts.status_name,
        ts.color_hex,
        t.created_at,
        t.user_create,
        -- Datos relacionados
        r.name_route,
        r.color_route,
        d.name_driver,
        b.amb_code AS bus_code,
        b.capacity_bus AS bus_capacity
      FROM tab_trips t
      LEFT JOIN tab_trip_statuses ts ON t.id_status = ts.id_status
      LEFT JOIN tab_routes r ON t.id_route = r.id_route
      LEFT JOIN tab_drivers d ON t.id_driver = d.id_driver
      LEFT JOIN tab_buses b ON t.id_bus = b.id_bus
      WHERE t.is_active = TRUE
    `;

    const params = [];
    let paramCounter = 1;

    // Agregar filtros dinámicamente
    if (status_trip !== undefined && isValidStatus(status_trip)) {
      query += ` AND t.id_status = $${paramCounter}`;
      params.push(status_trip);
      paramCounter++;
    }

    if (id_route) {
      query += ` AND t.id_route = $${paramCounter}`;
      params.push(id_route);
      paramCounter++;
    }

    if (id_driver) {
      query += ` AND t.id_driver = $${paramCounter}`;
      params.push(id_driver);
      paramCounter++;
    }

    if (plate_number) {
      query += ` AND b.plate_number = $${paramCounter}`;
      params.push(plate_number);
      paramCounter++;
    }

    // Filtro por fecha exacta
    if (trip_date) {
      query += ` AND t.trip_date = $${paramCounter}::DATE`;
      params.push(trip_date);
      paramCounter++;
    }

    // Filtro por rango de fechas usando epoch (convertir a DATE + TIME)
    if (from_epoch) {
      // Convertir epoch a fecha (solo día, sin hora)
      const fromDate = new Date(from_epoch * 1000);
      const dateStr = fromDate.toISOString().split('T')[0];
      query += ` AND t.trip_date >= $${paramCounter}::DATE`;
      params.push(dateStr);
      paramCounter++;
    }

    if (to_epoch) {
      // Convertir epoch a fecha (solo día, sin hora)
      const toDate = new Date(to_epoch * 1000);
      const dateStr = toDate.toISOString().split('T')[0];
      query += ` AND t.trip_date <= $${paramCounter}::DATE`;
      params.push(dateStr);
      paramCounter++;
    }

    // Ordenar por fecha y hora de inicio
    query += ` ORDER BY t.trip_date ASC, t.start_time ASC`;

    // Paginación
    query += ` LIMIT $${paramCounter} OFFSET $${paramCounter + 1}`;
    params.push(limit, offset);

    const result = await pool.query(query, params);

    return result.rows;
  } catch (error) {
    console.error('Error en listTrips:', error);
    throw error;
  }
}

/**
 * Obtiene eventos de un viaje (historial de cambios)
 * @param {number} idTrip - ID del viaje
 * @returns {Promise<Array>} - Array de eventos ordenados cronológicamente
 */
async function getTripEvents(idTrip) {
  try {
    const query = `
      SELECT 
        e.id_event,
        e.id_trip,
        e.event_type,
        e.old_status,
        ps.status_name as old_status_name,
        e.new_status,
        ns.status_name as new_status_name,
        e.event_data,
        e.performed_by,
        u.full_name as performed_by_name,
        e.performed_at
      FROM tab_trip_events e
      LEFT JOIN tab_trip_statuses ps ON e.old_status = ps.id_status
      LEFT JOIN tab_trip_statuses ns ON e.new_status = ns.id_status
      LEFT JOIN tab_users u ON e.performed_by = u.id_user
      WHERE e.id_trip = $1
      ORDER BY e.performed_at ASC;
    `;

    const result = await pool.query(query, [idTrip]);

    return result.rows;
  } catch (error) {
    console.error('Error en getTripEvents:', error);
    throw error;
  }
}

/**
 * Cuenta total de viajes según filtros
 * Útil para paginación en el frontend
 * @param {Object} filters - Mismos filtros que listTrips
 * @returns {Promise<number>} - Total de viajes que cumplen los filtros
 */
async function countTrips(filters = {}) {
  const {
    status_trip,
    id_route,
    id_driver,
    plate_number,
    trip_date,
    from_epoch,
    to_epoch
  } = filters;

  try {
    let query = `SELECT COUNT(*) as total FROM tab_trips WHERE is_active = TRUE`;

    const params = [];
    let paramCounter = 1;

    if (status_trip !== undefined && isValidStatus(status_trip)) {
      query += ` AND id_status = $${paramCounter}`;
      params.push(status_trip);
      paramCounter++;
    }

    if (id_route) {
      query += ` AND id_route = $${paramCounter}`;
      params.push(id_route);
      paramCounter++;
    }

    if (id_driver) {
      query += ` AND id_driver = $${paramCounter}`;
      params.push(id_driver);
      paramCounter++;
    }

    if (plate_number) {
      query += ` AND EXISTS (SELECT 1 FROM tab_buses b WHERE b.id_bus = id_bus AND b.plate_number = $${paramCounter})`;
      params.push(plate_number);
      paramCounter++;
    }

    if (trip_date) {
      query += ` AND trip_date = $${paramCounter}::DATE`;
      params.push(trip_date);
      paramCounter++;
    }

    if (from_epoch) {
      const fromDate = new Date(from_epoch * 1000).toISOString().split('T')[0];
      query += ` AND trip_date >= $${paramCounter}::DATE`;
      params.push(fromDate);
      paramCounter++;
    }

    if (to_epoch) {
      const toDate = new Date(to_epoch * 1000).toISOString().split('T')[0];
      query += ` AND trip_date <= $${paramCounter}::DATE`;
      params.push(toDate);
      paramCounter++;
    }

    const result = await pool.query(query, params);

    return parseInt(result.rows[0].total, 10);
  } catch (error) {
    console.error('Error en countTrips:', error);
    throw error;
  }
}

/**
 * Actualiza un viaje existente (campos operativos y transiciones de estado 1-4)
 * Para cancelar un viaje (status=5) usar cancelTrip().
 * @param {number} id_trip - ID del viaje a actualizar
 * @param {Object} updateData - Datos a actualizar (todos opcionales salvo user_update)
 * @param {number} [updateData.id_route] - Nueva ruta
 * @param {string} [updateData.trip_date] - Nueva fecha (YYYY-MM-DD)
 * @param {string} [updateData.start_time] - Nueva hora de inicio
 * @param {string} [updateData.end_time] - Nueva hora de fin
 * @param {number} [updateData.id_bus] - Nuevo bus (0 = desasignar)
 * @param {number} [updateData.id_driver] - Nuevo conductor (0 = desasignar)
 * @param {number} [updateData.id_status] - Nuevo estado (1=pendiente, 2=asignado, 3=activo, 4=completado)
 * @param {number} updateData.user_update - ID del usuario que actualiza
 * @returns {Promise<Object>} - { success, msg, error_code, id_trip }
 */
async function updateTrip(id_trip, updateData) {
  const {
    id_route    = null,
    trip_date   = null,
    start_time  = null,
    end_time    = null,
    id_bus      = null,
    id_driver   = null,
    id_status   = null,
    user_update = -1
  } = updateData;

  if (!id_trip) {
    return {
      success: false,
      msg: 'Falta parámetro requerido: id_trip',
      error_code: 'MISSING_PARAMS'
    };
  }

  // No permitir quitar bus/conductor en viajes activos o completados
  if (id_bus === 0 || id_driver === 0) {
    const check = await pool.query(
      'SELECT id_status FROM tab_trips WHERE id_trip = $1 AND is_active = TRUE',
      [id_trip]
    );
    if (check.rows.length && [3, 4].includes(check.rows[0].id_status)) {
      const label = check.rows[0].id_status === 3 ? 'activo' : 'completado';
      return {
        success: false,
        msg: `No se puede desasignar bus/conductor de un viaje ${label}`,
        error_code: 'TRIP_STATUS_INVALID'
      };
    }
  }

  try {
    const query = `
      SELECT success, msg, error_code, out_id_trip FROM fun_update_trip(
        $1::INTEGER,   -- wid_trip
        $2::SMALLINT,  -- wuser_update
        $3::SMALLINT,  -- wid_route
        $4::DATE,      -- wtrip_date
        $5::TIME,      -- wstart_time
        $6::TIME,      -- wend_time
        $7::SMALLINT,  -- wid_bus
        $8::BIGINT,    -- wid_driver
        $9::SMALLINT   -- wid_status
      );
    `;

    const values = [id_trip, user_update, id_route, trip_date, start_time, end_time, id_bus, id_driver, id_status];
    const result = await pool.query(query, values);

    return result.rows[0];
  } catch (error) {
    console.error('Error en updateTrip:', error);
    return {
      success: false,
      msg: `Error al actualizar viaje: ${error.message}`,
      error_code: 'DB_ERROR'
    };
  }
}

/**
 * Cancela un viaje individual (soft delete)
 * @param {number} idTrip - ID del viaje a cancelar
 * @param {number} userCancel - ID del usuario que cancela
 * @param {string} [cancellationReason] - Razón de cancelación (obligatorio para activos)
 * @param {boolean} [forceCancel=false] - Forzar cancelación de viajes activos
 * @returns {Promise<Object>} - Resultado de la operación
 */
async function cancelTrip(idTrip, userCancel, cancellationReason = null, forceCancel = false) {
  if (!idTrip || !userCancel) {
    return { success: false, msg: 'Faltan parámetros requeridos: idTrip, userCancel', error_code: 'MISSING_PARAMS' };
  }

  try {
    const query = `
      SELECT success, msg, error_code FROM fun_cancel_trip(
        $1::INTEGER,   -- wid_trip
        $2::SMALLINT,  -- wuser_cancel
        $3::TEXT,      -- wcancellation_reason
        $4::BOOLEAN    -- wforce_cancel
      );
    `;

    const result = await pool.query(query, [idTrip, userCancel, cancellationReason, forceCancel]);
    return result.rows[0];
  } catch (error) {
    console.error('Error en cancelTrip:', error);
    return { success: false, msg: `Error al cancelar viaje: ${error.message}`, error_code: 'DB_ERROR' };
  }
}

/**
 * Cancela múltiples viajes de una ruta en una fecha específica (batch)
 * @param {number} idRoute - ID de la ruta
 * @param {string} tripDate - Fecha de los viajes (YYYY-MM-DD)
 * @param {number} userCancel - ID del usuario que cancela
 * @param {string} [cancellationReason] - Razón de cancelación
 * @param {boolean} [forceCancelActive=false] - Forzar cancelación de viajes activos
 * @returns {Promise<Object>} - Resultado con contadores y IDs cancelados
 */
async function cancelTripsBatch(idRoute, tripDate, userCancel, cancellationReason = null, forceCancelActive = false) {
  // Validación básica
  if (!idRoute || !tripDate || !userCancel) {
    return {
      success: false,
      msg: 'Faltan parámetros requeridos: idRoute, tripDate, userCancel',
      error_code: 'MISSING_PARAMS'
    };
  }

  try {
    // Llamar a la stored function fun_cancel_trips_batch
    const query = `
      SELECT success, msg, error_code, trips_cancelled, trips_active_skipped, cancelled_ids FROM fun_cancel_trips_batch(
        $1::SMALLINT,  -- wid_route
        $2::DATE,      -- wtrip_date
        $3::SMALLINT,  -- wuser_cancel
        $4::TEXT,      -- wcancellation_reason
        $5::BOOLEAN    -- wforce_cancel_active
      );
    `;

    const values = [idRoute, tripDate, userCancel, cancellationReason, forceCancelActive];
    const result = await pool.query(query, values);

    // La función retorna columnas OUT directamente
    const response = result.rows[0];

    return response;
  } catch (error) {
    console.error('Error en cancelTripsBatch:', error);
    return {
      success: false,
      msg: `Error al cancelar viajes en lote: ${error.message}`,
      error_code: 'DB_ERROR'
    };
  }
}

export {
  createTrip,
  createTripsInBatch,
  getTripById,
  listTrips,
  getTripEvents,
  countTrips,
  updateTrip,
  cancelTrip,
  cancelTripsBatch
};
