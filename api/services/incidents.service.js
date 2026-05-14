import pool from '../config/database.js'

class IncidentsService {
  /**
   * Crea un nuevo incidente (reportado por conductor)
   */
  async createIncident(data) {
    const { tripId, incidentId, descrip, lat, lng } = data

    try {
      const result = await pool.query(
        `SELECT * FROM fun_create_incident($1, $2, $3, $4, $5)`,
        [tripId, incidentId, lat, lng, descrip || null]
      )

      const row = result.rows[0]
      if (!row.success) {
        throw new Error(row.msg)
      }

      return {
        success: true,
        incidentId: row.out_id_trip_incident,
        message: row.msg
      }
    } catch (error) {
      console.error('[IncidentsService] Error en createIncident:', error.message)
      throw error
    }
  }

  /**
   * Resuelve un incidente activo (por el administrador)
   */
  async resolveIncident(incidentId) {
    try {
      const result = await pool.query(
        `SELECT * FROM fun_resolve_incident($1)`,
        [incidentId]
      )

      const row = result.rows[0]
      if (!row.success) {
        throw new Error(row.msg)
      }

      return {
        success: true,
        message: row.msg
      }
    } catch (error) {
      console.error('[IncidentsService] Error en resolveIncident:', error.message)
      throw error
    }
  }

  /**
   * Obtiene todos los incidentes activos (para la app pasajero)
   */
  async getActiveIncidents() {
    try {
      // JOIN simple para enviar placa y ruta si se necesita en el frontend
      const query = `
        SELECT 
          i.id_trip_incident as "id",
          it.name_incident as "name",
          it.tag_incident as "tag",
          i.descrip_incident as "descrip",
          ST_Y(i.location_incident) as "lat",
          ST_X(i.location_incident) as "lng",
          i.created_at as "timestamp",
          t.id_trip as "tripId",
          b.plate_number as "plateNumber",
          r.id_route as "routeId"
        FROM tab_trip_incidents i
        JOIN tab_incident_types it ON i.id_incident = it.id_incident
        JOIN tab_trips t ON i.id_trip = t.id_trip
        LEFT JOIN tab_buses b ON t.id_bus = b.id_bus
        LEFT JOIN tab_routes r ON t.id_route = r.id_route
        WHERE i.status_incident = 'active'
        ORDER BY i.created_at DESC
      `
      const result = await pool.query(query)
      return result.rows
    } catch (error) {
      console.error('[IncidentsService] Error en getActiveIncidents:', error.message)
      throw error
    }
  }
}

export default new IncidentsService()
