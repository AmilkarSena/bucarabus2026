import pool from '../config/database.js'

const SYSTEM_USER_ID = 1;

/**
 * 🗺️ Servicio de Rutas - Usa Procedimientos Almacenados
 * El backend solo hace llamadas a los SPs de PostgreSQL
 */
class RoutesService {
  
  /**
   * Obtener todas las rutas
   */
  async getAllRoutes() {
    try {
      const result = await pool.query(`
        SELECT 
          r.id_route,
          r.name_route,
          ST_AsGeoJSON(r.path_route)::json as path_route,
          r.descrip_route,
          r.color_route,
          r.id_company,
          r.first_trip,
          r.last_trip,
          r.departure_route_sign,
          r.return_route_sign,
          r.route_fare,
          r.is_circular,
          r.is_active,
          r.created_at,
          r.updated_at,
          r.user_create,
          r.user_update,
          COALESCE(
            JSON_AGG(
              JSON_BUILD_OBJECT(
                'id_point', p.id_point,
                'name_point', p.name_point,
                'lat', ST_Y(p.location_point::geometry),
                'lng', ST_X(p.location_point::geometry),
                'point_order', a.point_order
              ) ORDER BY a.point_order
            ) FILTER (WHERE p.id_point IS NOT NULL),
            '[]'::json
          ) as stops
        FROM tab_routes r
        LEFT JOIN tab_route_points_assoc a ON r.id_route = a.id_route
        LEFT JOIN tab_route_points p ON a.id_point = p.id_point
        GROUP BY r.id_route, r.name_route, r.path_route, r.descrip_route, r.color_route,
                 r.id_company, r.first_trip, r.last_trip, r.departure_route_sign, r.return_route_sign,
                 r.route_fare, r.is_circular, r.is_active, r.created_at, r.updated_at, r.user_create, r.user_update
        ORDER BY r.id_route
      `)
      
      // Transformar al formato del frontend
      return result.rows.map(row => ({
        id: row.id_route,  // ID numérico único
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,  // Código para display
        name: row.name_route,
        path: row.path_route?.coordinates?.map(([lng, lat]) => [lat, lng]) || [],
        description: row.descrip_route || '',
        color: row.color_route || '#ef4444',
        idCompany: row.id_company,
        firstTrip: row.first_trip,
        lastTrip: row.last_trip,
        departureRouteSign: row.departure_route_sign,
        returnRouteSign: row.return_route_sign,
        fare: row.route_fare ?? 0,
        isCircular: row.is_circular ?? true,
        isActive: row.is_active,
        visible: true,
        stops: row.stops || [],
        buses: [],
        created_at: row.created_at,
        updated_at: row.updated_at,
        user_create: row.user_create,
        user_update: row.user_update
      }))
    } catch (error) {
      console.error('❌ Error obteniendo rutas:', error)
      throw error
    }
  }
  /**
   * Obtener ruta por ID
   */
  async getRouteById(id) {
    const routeId = Number(id)  // ID ya es numérico, solo asegurar tipo
    
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ST_AsGeoJSON(path_route)::json as path_route,
          descrip_route,
          color_route,
          id_company,
          first_trip,
          last_trip,
          departure_route_sign,
          return_route_sign,
          route_fare,
          is_circular,
          is_active,
          created_at,
          updated_at,
          user_create,
          user_update
        FROM tab_routes 
        WHERE id_route = $1 AND is_active = TRUE
      `, [routeId])
      
      if (result.rows.length === 0) {
        return null
      }
      
      const row = result.rows[0]
      
      return {
        id: row.id_route,
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,
        name: row.name_route,
        path: row.path_route?.coordinates?.map(([lng, lat]) => [lat, lng]) || [],
        description: row.descrip_route || '',
        color: row.color_route || '#ef4444',
        idCompany: row.id_company,
        firstTrip: row.first_trip,
        lastTrip: row.last_trip,
        departureRouteSign: row.departure_route_sign,
        returnRouteSign: row.return_route_sign,
        fare: row.route_fare ?? 0,
        isCircular: row.is_circular ?? true,
        isActive: row.is_active,
        visible: true,
        trips: [],
        stops: [],
        buses: [],
        created_at: row.created_at,
        updated_at: row.updated_at,
        user_create: row.user_create,
        user_update: row.user_update
      }
    } catch (error) {
      console.error('❌ Error obteniendo ruta por ID:', error)
      throw error
    }
  }

  /**
   * Crear nueva ruta (v2) — ruta + paradas en una sola transacción.
   *
   * routeData espera:
   *   { name, color, description, path, stops, user, routeFare, isCircular,
   *     idCompany, firstTrip, lastTrip, departureRouteSign, returnRouteSign }
   *
   * stops: [{ id_point, dist_from_start?, eta_seconds? }, ...]  en orden secuencial.
   * path:  [[lat, lng], ...]  — polilínea calculada por OSRM en el frontend.
   */
  async createRoute(routeData) {
    const { name, color, description, path, stops, user, routeFare, isCircular } = routeData

    // ── Validaciones de backend ──────────────────────────────────────────────
    if (!name) {
      throw new Error('Nombre es requerido')
    }

    if (!stops || stops.length < 2) {
      throw new Error('Se requieren al menos 2 paradas para crear la ruta')
    }

    if (!path || path.length < 2) {
      throw new Error('Se requieren al menos 2 puntos de trayecto para crear la ruta')
    }
    
    // Convertir array de coordenadas [lat, lng] a GeoJSON LineString con [lng, lat]
    const geoJsonPath = JSON.stringify({
      type: 'LineString',
      coordinates: path.map(p => [p[1], p[0]])
    })

    // Serializar las paradas como JSONB para el SP v2
    // stops llega como [{ id_point, dist_from_start?, eta_seconds? }, ...]
    const stopsJson = JSON.stringify(
      stops.map((s, idx) => ({
        id_point:        s.id_point,
        dist_from_start: s.dist_from_start ?? null,
        eta_seconds:     s.eta_seconds ?? null
      }))
    )

    try {
      const result = await pool.query(
        `SELECT success, msg, error_code, out_id_route
         FROM fun_create_route($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)`,
        [
          name,
          geoJsonPath,
          color || '#ef4444',
          routeData.idCompany || null,
          user || SYSTEM_USER_ID,
          stopsJson,                          // $6 — JSONB array de paradas
          description || null,
          routeData.firstTrip || null,
          routeData.lastTrip || null,
          routeData.departureRouteSign || null,
          routeData.returnRouteSign || null,
          routeFare ?? 0,
          isCircular ?? false
        ]
      )

      const response = result.rows[0]

      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }

      // Obtener la ruta completa (ya incluirá las paradas asignadas)
      const newRoute = await this.getRouteById(response.out_id_route)

      return {
        ...newRoute,
        message: response.msg
      }
    } catch (error) {
      console.error('❌ Error creando ruta:', error.message)
      if (error.code) {
        console.error('   Código de error:', error.code)
      }
      throw error
    }
  }

   /**
   * Actualizar ruta existente (solo metadatos: nombre, color, descripción)
   */
  async updateRoute(id, routeData) {
    const routeId = Number(id)
    const { name, color, description, user, idCompany, firstTrip, lastTrip, departureRouteSign, returnRouteSign, routeFare, isCircular } = routeData
    
    try {
      const result = await pool.query(
        'SELECT success, msg, error_code, out_id_route FROM fun_update_route($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)',
        [
          routeId,
          name || null,
          color || null,
          idCompany || null,
          user || SYSTEM_USER_ID,
          description || null,
          firstTrip || null,
          lastTrip || null,
          departureRouteSign || null,
          returnRouteSign || null,
          routeFare ?? 0,
          isCircular ?? false
        ]
      )
      
      const response = result.rows[0]
      
      // Verificar si la operación fue exitosa
      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }
      
      // Buscar la ruta recién actualizada
      const updatedRoute = await this.getRouteById(response.out_id_route)
      
      return {
        ...updatedRoute,
        message: response.msg
      }
    } catch (error) {
      console.error('❌ Error actualizando ruta:', error.message)
      if (error.code) {
        console.error('   Código de error:', error.code)
      }
      throw error
    }
  }


  /**
   * Eliminar ruta (soft delete)
   */
  async deleteRoute(id, user) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(
        'SELECT success, msg, error_code, warning FROM fun_delete_route($1, $2)',
        [routeId, user || SYSTEM_USER_ID]
      )
      
      const response = result.rows[0]
      
      // Si no fue exitoso, lanzar error con código específico
      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }
      
      // Retornar éxito con advertencia si existe
      return {
        success: true,
        message: response.msg,
        warning: response.warning || null
      }
    } catch (error) {
      console.error('❌ Error eliminando ruta:', error.message)
      if (error.code) {
        console.error('   Código de error:', error.code)
      }
      throw error
    }
  }

  /**
   * Buscar rutas por nombre
   */
  async searchRoutes(searchTerm) {
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ST_AsGeoJSON(path_route)::json as path_route,
          descrip_route,
          color_route,
          is_active
        FROM tab_routes 
        WHERE is_active = TRUE 
          AND (name_route ILIKE $1 OR descrip_route ILIKE $1)
        ORDER BY name_route
      `, [`%${searchTerm}%`])
      
      return result.rows.map(row => ({
        id: row.id_route,
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,
        name: row.name_route,
        path: row.path_route?.coordinates?.map(([lng, lat]) => [lat, lng]) || [],
        description: row.descrip_route || '',
        color: row.color_route,
        isActive: row.is_active,
        visible: true,
        stops: [],
        buses: []
      }))
    } catch (error) {
      console.error('❌ Error buscando rutas:', error)
      throw error
    }
  }

  /**
   * Calcular distancia de ruta
   */
  async getRouteDistance(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(`
        SELECT 
          id_route,
          name_route,
          ROUND((ST_Length(ST_SetSRID(path_route, 4326)::geography) / 1000)::numeric, 2) as distance_km
        FROM tab_routes 
        WHERE id_route = $1 AND is_active = TRUE
      `, [routeId])
      
      if (result.rows.length === 0) {
        return null
      }
      
      return {
        id: result.rows[0].id_route,
        code: `RUTA_${String(result.rows[0].id_route).padStart(2, '0')}`,
        name: result.rows[0].name_route,
        distance_km: result.rows[0].distance_km
      }
    } catch (error) {
      console.error('❌ Error calculando distancia:', error)
      throw error
    }
  }


  /**
   * Obtener cantidad de viajes activos o pendientes de una ruta
   */
  async getActiveTripsCount(id) {
    const routeId = Number(id)
    try {
      const checkResult = await pool.query(
        `SELECT COUNT(*) FROM tab_trips 
         WHERE id_route = $1 
         AND id_status IN (1, 2, 3) 
         AND is_active = TRUE`,
        [routeId]
      )
      return {
        success: true,
        count: parseInt(checkResult.rows[0].count)
      }
    } catch (error) {
      console.error('❌ Error obteniendo viajes activos de la ruta:', error)
      throw error
    }
  }

  /**
   * Obtener viajes de una ruta
   */
  async getRouteTrips(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(`
        SELECT 
          id_trip,
          id_route,
          trip_date,
          start_time,
          end_time,
          plate_number,
          status_trip,
          created_at,
          user_create
        FROM tab_trips 
        WHERE id_route = $1
        ORDER BY trip_date DESC, start_time ASC
      `, [routeId])
      
      return result.rows
    } catch (error) {
      console.error('❌ Error obteniendo viajes:', error)
      throw error
    }
  }

  /**
   * Obtener estadísticas de una ruta
   */
  async getRouteStats(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(`
        SELECT 
          r.id_route,
          r.name_route,
          ROUND(ST_Length(r.path_route::geography) / 1000, 2) as distance_km,
          COUNT(DISTINCT t.id_trip) FILTER (WHERE t.is_active = TRUE) as total_trips,
          COUNT(DISTINCT t.plate_number) FILTER (WHERE t.is_active = TRUE) as assigned_buses,
          COUNT(DISTINCT CASE WHEN t.id_status = 3 AND t.is_active = TRUE THEN t.id_trip END) as active_trips
        FROM tab_routes r
        LEFT JOIN tab_trips t ON r.id_route = t.id_route
        WHERE r.id_route = $1 AND r.is_active = TRUE
        GROUP BY r.id_route, r.name_route, r.path_route
      `, [routeId])
      
      if (result.rows.length === 0) {
        return null
      }
      
      const row = result.rows[0]
      
      return {
        id: row.id_route,
        code: `RUTA_${String(row.id_route).padStart(2, '0')}`,
        name: row.name_route,
        distance_km: parseFloat(row.distance_km) || 0,
        total_trips: parseInt(row.total_trips) || 0,
        assigned_buses: parseInt(row.assigned_buses) || 0,
        active_trips: parseInt(row.active_trips) || 0
      }
    } catch (error) {
      console.error('❌ Error obteniendo estadísticas:', error)
      throw error
    }
  }

  /**
   * Alternar visibilidad (solo frontend, no BD)
   */
  async toggleVisibility(id) {
    const routeId = Number(id)
    
    try {
      const result = await pool.query(
        'SELECT id_route FROM tab_routes WHERE id_route = $1 AND is_active = TRUE',
        [routeId]
      )
      
      if (result.rows.length === 0) {
        return null
      }
      
      return {
        id: result.rows[0].id_route,
        code: `RUTA_${String(result.rows[0].id_route).padStart(2, '0')}`,
        visible: true
      }
    } catch (error) {
      console.error('❌ Error alternando visibilidad:', error)
      throw error
    }
  }

  /**
   * Alternar estado activo de una ruta
   */
  async toggleRoute(id, isActive, userUpdate) {
    const routeId = Number(id)
    try {
      // Validar que no haya viajes pendientes/activos si se intenta inactivar la ruta
      if (isActive === false || isActive === 'false') {
        const checkResult = await pool.query(
          `SELECT COUNT(*) FROM tab_trips 
           WHERE id_route = $1 
           AND id_status IN (1, 2, 3) 
           AND is_active = TRUE`,
          [routeId]
        )
        const activeTripsCount = parseInt(checkResult.rows[0].count)
        if (activeTripsCount > 0) {
          const error = new Error(`No se puede inactivar la ruta porque tiene ${activeTripsCount} viaje(s) pendiente(s), asignado(s) o en curso.`)
          error.code = 'ACTIVE_TRIPS_EXIST'
          throw error
        }
      }

      const result = await pool.query(
        'SELECT success, msg, error_code, out_id_route, new_status FROM fun_toggle_route($1, $2, $3)',
        [routeId, isActive, userUpdate || SYSTEM_USER_ID]
      )

      const response = result.rows[0]

      if (!response.success) {
        const error = new Error(response.msg)
        error.code = response.error_code
        throw error
      }

      return {
        success: true,
        message: response.msg,
        route: {
          id: response.out_id_route,
          isActive: response.new_status
        }
      }
    } catch (error) {
      console.error('❌ Error alternando estado de ruta:', error)
      throw error
    }
  }

  /**
   * Obtener los puntos asignados a una ruta
   */
  async getRoutePoints(idRoute) {
    const routeId = Number(idRoute)
    try {
      const result = await pool.query(`
        SELECT 
          ap.id_point,
          p.name_point,
          p.descrip_point,
          ST_Y(p.location_point::geometry) as lat,
          ST_X(p.location_point::geometry) as lng,
          ap.point_order,
          ap.dist_from_start,
          ap.eta_seconds,
          p.is_active as point_is_active
        FROM tab_route_points_assoc ap
        JOIN tab_route_points p ON ap.id_point = p.id_point
        WHERE ap.id_route = $1
        ORDER BY ap.point_order ASC
      `, [routeId])

      return result.rows.map(row => ({
        idPoint:       row.id_point,
        namePoint:     row.name_point,
        descripPoint:  row.descrip_point,
        coordinates:   [parseFloat(row.lat), parseFloat(row.lng)],
        pointOrder:    row.point_order,
        distFromStart: row.dist_from_start,
        etaSeconds:    row.eta_seconds,
        isActive:      row.point_is_active
      }))
    } catch (error) {
      console.error('❌ Error obteniendo puntos de ruta:', error)
      throw error
    }
  }

  /**
   * Asignar un punto a una ruta
   */
  async assignRoutePoint(idRoute, pointData) {
    const routeId = Number(idRoute)
    const { idPoint, pointOrder, distFromStart, etaSeconds } = pointData

    try {
      const result = await pool.query(
        'SELECT success, msg, error_code, out_id_route, out_id_point, out_point_order FROM fun_assign_route_point($1, $2, $3, $4, $5)',
        [
          routeId,
          Number(idPoint),
          Number(pointOrder),
          distFromStart != null ? Number(distFromStart) : null,
          etaSeconds != null ? Number(etaSeconds) : null
        ]
      )

      const response = result.rows[0]

      if (!response.success) {
        const err = new Error(response.msg)
        err.code = response.error_code || 'ROUTE_POINT_ASSOC_ERROR'
        throw err
      }

      return {
        success: true,
        idRoute: response.out_id_route,
        idPoint: response.out_id_point,
        pointOrder: response.out_point_order,
        message: response.msg
      }
    } catch (error) {
      console.error('❌ Error asignando punto de ruta:', error)
      throw error
    }
  }

  /**
   * Desasignar un punto de una ruta
   */
  async unassignRoutePoint(idRoute, idPoint) {
    try {
      const result = await pool.query(
        'SELECT success, msg, error_code, out_id_route, out_id_point, out_point_order FROM fun_unassign_route_point($1, $2)',
        [Number(idRoute), Number(idPoint)]
      )

      const { success, msg, error_code, out_id_route, out_id_point, out_point_order } = result.rows[0]

      if (!success) {
        const err = new Error(msg)
        err.code = error_code
        throw err
      }

      return {
        success:    true,
        idRoute:    out_id_route,
        idPoint:    out_id_point,
        pointOrder: out_point_order,
        message:    msg
      }
    } catch (error) {
      console.error('❌ Error desasignando punto de ruta:', error)
      throw error
    }
  }

  /**
   * Reordenar los puntos de una ruta
   * @param {number} idRoute
   * @param {Array<{idPoint: number, order: number}>} orderArray
   */
  async reorderRoutePoints(idRoute, orderArray) {
    const routeId = Number(idRoute)
    // fun_reorder_route_points espera: [{id_point, order}]
    const orderJson = JSON.stringify(orderArray.map(item => ({
      id_point: Number(item.idPoint),
      order: Number(item.order)
    })))

    try {
      const result = await pool.query(
        'SELECT success, msg, error_code, updated_count FROM fun_reorder_route_points($1, $2)',
        [routeId, orderJson]
      )

      const response = result.rows[0]

      if (!response.success) {
        const err = new Error(response.msg)
        err.code = response.error_code
        throw err
      }

      return {
        success:      true,
        updatedCount: response.updated_count,
        message:      response.msg
      }
    } catch (error) {
      console.error('❌ Error reordenando puntos de ruta:', error)
      throw error
    }
  }
}

export default new RoutesService()
