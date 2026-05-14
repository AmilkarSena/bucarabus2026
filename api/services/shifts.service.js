import pool from '../config/database.js';
import { listTrips, updateTrip } from './trips.service.js';
// Estados: 1=pendiente, 2=asignado, 3=activo, 4=completado, 5=cancelado — ver tab_trip_statuses

/** Fecha de hoy como string YYYY-MM-DD (Ajustada a Colombia UTC-5) */
const todayStr = () => {
    const colDate = new Date(new Date().getTime() - (5 * 60 * 60 * 1000));
    return colDate.toISOString().split('T')[0];
};

/** Hora local actual como string HH:MM:SS (Ajustada a Colombia UTC-5) */
const localTimeStr = () => {
    const colDate = new Date(new Date().getTime() - (5 * 60 * 60 * 1000));
    return colDate.toISOString().split('T')[1].substring(0, 8);
};

/**
 * Obtener todos los turnos activos Y programados en rango horario.
 * Primero llama a fun_finalize_expired_trips para cerrar viajes vencidos (lazy).
 */
async function getActiveShifts() {
    const today = todayStr();

    // Auto-activar viajes cuyo start_time ya llegó (y end_time aún no ha pasado)
    await pool.query('SELECT fun_auto_activate_trips($1::DATE, $2::TIME)', [today, localTimeStr()]);
    // Auto-finalizar viajes cuyo end_time ya pasó
    await pool.query('SELECT fun_finalize_expired_trips($1::DATE, $2::TIME)', [today, localTimeStr()]);

    const query = `
        SELECT 
            t.id_trip,
            b.plate_number,
            t.id_route,
            t.start_time as started_at,
            t.end_time,
            t.id_status AS status_trip,
            t.trip_date,
            b.amb_code,
            b.capacity_bus AS capacity,
            t.id_driver,
            d.name_driver,
            d.phone_driver AS driver_phone,
            r.name_route,
            r.color_route,
            ST_AsGeoJSON(r.path_route) as path_geojson,
            CASE 
                WHEN t.id_status = 3 THEN true
                ELSE false
            END as gps_active,
            NULL as current_lat,
            NULL as current_lng,
            (
                SELECT COUNT(*)
                FROM tab_trips t2
                WHERE t2.id_bus = t.id_bus
                AND t2.id_status = 4
                AND t2.trip_date = $1::DATE
                AND t2.is_active = TRUE
            ) as trips_completed,
            CASE 
                WHEN t.start_time IS NOT NULL AND t.end_time IS NOT NULL
                     AND t.end_time > t.start_time THEN
                    LEAST(100, GREATEST(0, 
                        ROUND(
                            (EXTRACT(EPOCH FROM (NOW()::TIME - t.start_time)) / 
                            EXTRACT(EPOCH FROM (t.end_time - t.start_time))) * 100
                        )::numeric
                    ))
                ELSE 0
            END as progress_percentage
        FROM tab_trips t
        JOIN tab_buses b ON b.id_bus = t.id_bus
        LEFT JOIN tab_drivers d ON d.id_driver = t.id_driver
        JOIN tab_routes r ON t.id_route = r.id_route
        WHERE t.id_status IN (1, 2, 3, 4)
        AND t.trip_date = $1::DATE
        AND t.is_active = TRUE
        AND t.id_bus IS NOT NULL
        ORDER BY t.id_status ASC, t.start_time DESC
    `;

    const result = await pool.query(query, [today]);
    return result.rows.map(row => ({
        ...row,
        path_route: row.path_geojson ? JSON.parse(row.path_geojson) : null,
        gps_active: row.gps_active || false,
        progress_percentage: Number(row.progress_percentage) || 0,
        trips_completed: Number(row.trips_completed) || 0
    }));
}

/**
 * Obtener un turno activo por placa
 */
async function getActiveShiftByPlate(plateNumber) {
    const query = `
        SELECT 
            t.id_trip,
            b.plate_number,
            t.id_route,
            t.start_time as started_at,
            t.end_time,
            t.id_status AS status_trip,
            t.trip_date,
            b.amb_code,
            b.capacity_bus AS capacity,
            t.id_driver,
            d.name_driver,
            r.name_route,
            r.color_route,
            ST_AsGeoJSON(r.path_route) as path_geojson
        FROM tab_trips t
        JOIN tab_buses b ON b.id_bus = t.id_bus
        LEFT JOIN tab_drivers d ON d.id_driver = t.id_driver
        JOIN tab_routes r ON t.id_route = r.id_route
        WHERE b.plate_number = $1
        AND t.id_status = 3
        AND t.trip_date = CURRENT_DATE
        AND t.is_active = TRUE
    `;
    
    const result = await pool.query(query, [plateNumber]);
    if (result.rows.length === 0) return null;
    
    const row = result.rows[0];
    return {
        ...row,
        path_route: row.path_geojson ? JSON.parse(row.path_geojson) : null
    };
}

/**
 * Iniciar un turno: busca el viaje pendiente/asignado del bus para hoy
 * y lo transiciona a estado 3 (activo) via fun_update_trip.
 */
async function startShift(data) {
    const { plate_number, id_trip: providedTripId } = data;

    // Verificar si el bus ya tiene un turno activo
    const existing = await pool.query(
        `SELECT t.id_trip FROM tab_trips t
         JOIN tab_buses b ON b.id_bus = t.id_bus
         WHERE b.plate_number = $1 AND t.id_status = 3 AND t.trip_date = CURRENT_DATE AND t.is_active = TRUE`,
        [plate_number]
    );
    if (existing.rows.length > 0) {
        throw new Error('El bus ya tiene un turno activo');
    }

    // Resolver id_trip: puede venir del llamador o hay que buscarlo
    let id_trip = providedTripId;
    if (!id_trip) {
        const pending = await pool.query(
            `SELECT t.id_trip FROM tab_trips t
             JOIN tab_buses b ON b.id_bus = t.id_bus
             WHERE b.plate_number = $1
               AND t.id_status IN (1, 2)
               AND t.trip_date = CURRENT_DATE
               AND t.is_active = TRUE
             ORDER BY t.start_time ASC
             LIMIT 1`,
            [plate_number]
        );
        if (pending.rows.length === 0) {
            throw new Error('No se encontró viaje pendiente o asignado para este bus hoy');
        }
        id_trip = pending.rows[0].id_trip;
    }

    // Delegar al stored procedure via trips.service
    const result = await updateTrip(id_trip, { id_status: 3, user_update: -1 });
    if (!result.success) throw new Error(result.msg);
    return result;
}

/**
 * Finalizar un turno: busca el viaje activo del bus hoy
 * y lo transiciona a estado 4 (completado) via fun_update_trip.
 */
async function endShift(plateNumber) {
    const active = await pool.query(
        `SELECT t.id_trip FROM tab_trips t
         JOIN tab_buses b ON b.id_bus = t.id_bus
         WHERE b.plate_number = $1
           AND t.id_status = 3
           AND t.trip_date = CURRENT_DATE
           AND t.is_active = TRUE
         LIMIT 1`,
        [plateNumber]
    );
    if (active.rows.length === 0) return null;

    const result = await updateTrip(active.rows[0].id_trip, { id_status: 4, user_update: -1 });
    if (!result.success) throw new Error(result.msg);
    return result;
}

/**
 * Verificar que existe un turno activo para la placa (el progreso se calcula
 * dinámicamente en getActiveShifts — no hay columnas progress/trips_completed en BD).
 */
async function updateProgress(plateNumber, _progress, _tripsCompleted) {
    const trips = await listTrips({
        status_trip: 3,
        plate_number: plateNumber,
        trip_date: todayStr(),
        limit: 1
    });
    return trips[0] || null;
}

/**
 * Obtener buses disponibles (sin turno activo)
 */
async function getAvailableBuses() {
    const query = `
        SELECT b.*
        FROM tab_buses b
        WHERE b.is_active = true
        AND b.id_bus NOT IN (
            SELECT id_bus FROM tab_trips 
            WHERE id_status = 3
            AND trip_date = CURRENT_DATE
            AND id_bus IS NOT NULL
            AND is_active = TRUE
        )
        ORDER BY b.amb_code
    `;
    
    const result = await pool.query(query);
    return result.rows;
}

/**
 * Obtener solo turnos asignados/pendientes en rango horario actual
 */
async function getScheduledShiftsInRange() {
    const query = `
        SELECT 
            t.id_trip,
            b.plate_number,
            t.id_route,
            t.start_time,
            t.end_time,
            t.id_status AS status_trip,
            t.trip_date,
            b.amb_code,
            d.name_driver,
            r.name_route,
            r.color_route
        FROM tab_trips t
        JOIN tab_buses b ON b.id_bus = t.id_bus
        LEFT JOIN tab_drivers d ON d.id_driver = t.id_driver
        JOIN tab_routes r ON t.id_route = r.id_route
        WHERE t.id_status IN (2, 1)
        AND t.trip_date = CURRENT_DATE
        AND t.is_active = TRUE
        AND CURRENT_TIME >= t.start_time
        AND CURRENT_TIME < t.end_time
        ORDER BY t.start_time ASC
    `;
    
    const result = await pool.query(query);
    return result.rows;
}

/**
 * [DEBUG] Obtener TODOS los viajes de hoy sin filtro horario.
 * Delega en listTrips para evitar SQL duplicado.
 */
async function getAllTodayTrips() {
    return listTrips({ trip_date: todayStr(), limit: 500 });
}

export {
    getActiveShifts,
    getActiveShiftByPlate,
    getScheduledShiftsInRange,
    startShift,
    endShift,
    updateProgress,
    getAvailableBuses,
    getAllTodayTrips
};
