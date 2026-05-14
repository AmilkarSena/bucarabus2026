import pool from '../config/database.js'

class AssignmentsService {
  /**
   * Asignar conductor a bus
   * @param {number} idBus        - ID del bus (id_bus de tab_buses)
   * @param {number} idDriver     - Cédula del conductor (id_driver de tab_drivers)
   * @param {number} assignedBy   - ID del usuario que realiza la asignación
   */
  async assignDriver(idBus, idDriver, assignedBy) {
    try {
      const result = await pool.query(
        `SELECT success, msg, error_code FROM fun_assign_driver($1, $2, $3)`,
        [idBus, idDriver, assignedBy]
      );
      const response = result.rows[0];
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en assignDriver:', error);
      return {
        success: false,
        message: 'Error interno: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Desasignar conductor activo de un bus
   * @param {number} idDriver     - Cédula del conductor a desasignar
   * @param {number} unassignedBy - ID del usuario que realiza la desasignación
   */
  async unassignDriver(idDriver, unassignedBy) {
    try {
      const result = await pool.query(
        `SELECT success, msg, error_code FROM fun_unassign_driver($1, $2)`,
        [idDriver, unassignedBy]
      );
      const response = result.rows[0];
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en unassignDriver:', error);
      return {
        success: false,
        message: 'Error interno: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Obtener asignación activa de un bus
   * @param {string} plateNumber - Placa del bus
   */
  async getActiveAssignment(idBus) {
    try {
      const result = await pool.query(`
        SELECT
          a.id_bus,
          a.id_driver,
          d.name_driver,
          a.assigned_at,
          a.assigned_by
        FROM tab_bus_assignments a
        JOIN tab_drivers d ON a.id_driver = d.id_driver
        WHERE a.id_bus = $1
          AND a.unassigned_at IS NULL
      `, [idBus]);

      return { success: true, data: result.rows[0] || null };
    } catch (error) {
      console.error('Error en getActiveAssignment:', error);
      return { success: false, message: error.message };
    }
  }

  /**
   * Obtener historial completo de asignaciones de un bus
   * @param {number} idBus - ID del bus
   */
  async getBusHistory(idBus) {
    try {
      const result = await pool.query(`
        SELECT
          a.id_bus,
          a.id_driver,
          d.name_driver,
          a.assigned_at,
          a.unassigned_at,
          a.assigned_by,
          a.unassigned_by
        FROM tab_bus_assignments a
        JOIN tab_drivers d ON a.id_driver = d.id_driver
        WHERE a.id_bus = $1
        ORDER BY a.assigned_at DESC
      `, [idBus]);

      return { success: true, data: result.rows };
    } catch (error) {
      console.error('Error en getBusHistory:', error);
      return { success: false, message: error.message };
    }
  }
}

export default new AssignmentsService();
