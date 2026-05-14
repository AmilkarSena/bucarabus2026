import pool from '../config/database.js';

/**
 * Guardar snapshot GPS en histórico
 * Se llama cada 10 minutos desde la app del conductor
 */
export async function saveGPSSnapshot(data) {
    const { id_trip, lat, lng, speed } = data;
    
    const query = `
        INSERT INTO tab_trip_gps_history 
        (id_trip, gps_location, speed, recorded_at)
        VALUES ($1, ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, NOW())
        RETURNING 
            id_gps_record,
            id_trip,
            ST_Y(gps_location::geometry) as lat,
            ST_X(gps_location::geometry) as lng,
            speed,
            recorded_at
    `;
    
    const result = await pool.query(query, [
        id_trip,
        lng,  // PostGIS usa (lng, lat) en ST_MakePoint
        lat,
        speed || null
    ]);
    
    return result.rows[0];
}

/**
 * Obtener histórico GPS de un viaje completo
 */
export async function getTripGPSHistory(id_trip) {
    const query = `
        SELECT 
            id_gps_record,
            ST_Y(gps_location::geometry) as lat,
            ST_X(gps_location::geometry) as lng,
            speed,
            recorded_at
        FROM tab_trip_gps_history
        WHERE id_trip = $1
        ORDER BY recorded_at ASC
    `;
    
    const result = await pool.query(query, [id_trip]);
    return result.rows;
}

/**
 * Obtener último snapshot GPS de un viaje
 */
export async function getLastGPSSnapshot(id_trip) {
    const query = `
        SELECT 
            id_gps_record,
            id_trip,
            ST_Y(gps_location::geometry) as lat,
            ST_X(gps_location::geometry) as lng,
            speed,
            recorded_at
        FROM tab_trip_gps_history
        WHERE id_trip = $1
        ORDER BY recorded_at DESC
        LIMIT 1
    `;
    
    const result = await pool.query(query, [id_trip]);
    return result.rows[0] || null;
}

/**
 * Obtener histórico GPS de todos los viajes de una fecha
 */
export async function getGPSHistoryByDate(trip_date) {
    const query = `
        SELECT 
            h.id_gps_record,
            h.id_trip,
            ST_Y(h.gps_location::geometry) as lat,
            ST_X(h.gps_location::geometry) as lng,
            h.speed,
            h.recorded_at,
            t.id_route,
            t.plate_number,
            t.start_time,
            t.end_time,
            r.name_route,
            b.amb_code
        FROM tab_trip_gps_history h
        JOIN tab_trips t ON h.id_trip = t.id_trip
        JOIN tab_routes r ON t.id_route = r.id_route
        LEFT JOIN tab_buses b ON t.plate_number = b.plate_number
        WHERE t.trip_date = $1
        ORDER BY h.recorded_at ASC
    `;
    
    const result = await pool.query(query, [trip_date]);
    return result.rows;
}

/**
 * Calcular estadísticas de un viaje desde el histórico GPS
 */
export async function getTripStatistics(id_trip) {
    const query = `
        WITH gps_data AS (
            SELECT 
                gps_location,
                speed,
                recorded_at,
                LAG(gps_location) OVER (ORDER BY recorded_at) as prev_location,
                LAG(recorded_at) OVER (ORDER BY recorded_at) as prev_time
            FROM tab_trip_gps_history
            WHERE id_trip = $1
            ORDER BY recorded_at
        ),
        distances AS (
            SELECT
                -- Usar ST_DistanceSphere de PostGIS (devuelve metros)
                ST_DistanceSphere(prev_location, gps_location) / 1000.0 as distance_km,
                EXTRACT(EPOCH FROM (recorded_at - prev_time)) / 60 as time_diff_minutes,
                speed
            FROM gps_data
            WHERE prev_location IS NOT NULL
        )
        SELECT
            COUNT(*) as total_snapshots,
            COALESCE(SUM(distance_km), 0) as total_distance_km,
            COALESCE(AVG(speed), 0) as avg_speed_kmh,
            COALESCE(MAX(speed), 0) as max_speed_kmh,
            COALESCE(SUM(time_diff_minutes), 0) as total_duration_minutes
        FROM distances
    `;
    
    const result = await pool.query(query, [id_trip]);
    return result.rows[0];
}

/**
 * Limpiar histórico antiguo (más de X días)
 */
export async function cleanupOldGPSHistory(days = 90) {
    const query = `
        DELETE FROM tab_trip_gps_history
        WHERE recorded_at < NOW() - INTERVAL '${days} days'
        RETURNING COUNT(*) as deleted_count
    `;
    
    const result = await pool.query(query);
    return result.rows[0];
}

export default {
    saveGPSSnapshot,
    getTripGPSHistory,
    getLastGPSSnapshot,
    getGPSHistoryByDate,
    getTripStatistics,
    cleanupOldGPSHistory
};
