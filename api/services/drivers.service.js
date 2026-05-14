import pool from '../config/database.js'

// =============================================
// DriversService v2.1
// Arquitectura: tab_drivers (cédula = PK)
// Vínculo con tab_users → tab_driver_accounts (tabla puente)
// Funciones BD: fun_create_driver, fun_update_driver
// =============================================

const BASE_SELECT = `
  SELECT
    d.id_driver,
    da.id_user,
    d.name_driver,
    d.address_driver,
    d.phone_driver,
    d.email_driver,
    d.birth_date,
    d.gender_driver,
    d.license_cat,
    d.license_exp,
    d.id_eps,
    e.name_eps,
    d.id_arl,
    a.name_arl,
    d.blood_type,
    d.emergency_contact,
    d.emergency_phone,
    d.date_entry,
    d.id_status,
    ds.status_name,
    ds.color_hex      AS status_color,
    d.is_active,
    d.created_at,
    d.updated_at,
    d.user_create,
    d.user_update,
    ba.id_bus   AS assigned_bus,
    ba.assigned_at    AS assignment_date
  FROM tab_drivers d
  LEFT JOIN tab_driver_statuses ds ON ds.id_status  = d.id_status
  LEFT JOIN tab_eps              e  ON e.id_eps      = d.id_eps
  LEFT JOIN tab_arl              a  ON a.id_arl      = d.id_arl
  LEFT JOIN tab_bus_assignments  ba ON ba.id_driver  = d.id_driver
                                   AND ba.unassigned_at IS NULL
  LEFT JOIN tab_driver_accounts  da ON da.id_driver  = d.id_driver
`

class DriversService {
  /**
   * Obtener todos los conductores
   * @param {boolean} onlyActive - Si true, solo retorna conductores activos
   */
  async getAllDrivers(onlyActive = false) {
    try {
      let query = BASE_SELECT
      if (onlyActive) query += ' WHERE d.is_active = TRUE'
      query += ' ORDER BY d.name_driver'
      const result = await pool.query(query)
      return { success: true, data: result.rows }
    } catch (error) {
      console.error('Error en getAllDrivers:', error)
      throw error
    }
  }

  /**
   * Obtener conductor por cédula
   * @param {number|string} idDriver - Cédula del conductor
   */
  async getDriverById(idDriver) {
    try {
      const result = await pool.query(
        BASE_SELECT + ' WHERE d.id_driver = $1',
        [idDriver]
      )
      if (result.rows.length === 0) {
        return { success: false, message: 'Conductor no encontrado' }
      }
      return { success: true, data: result.rows[0] }
    } catch (error) {
      console.error('Error en getDriverById:', error)
      throw error
    }
  }

  /**
   * Obtener conductores disponibles (id_status=1, activos, licencia vigente, sin bus asignado)
   */
  async getAvailableDrivers() {
    try {
      const result = await pool.query(`
        SELECT
          d.id_driver,
          d.name_driver,
          d.phone_driver,
          d.email_driver,
          d.license_cat,
          d.license_exp,
          d.id_status,
          ds.status_name
        FROM tab_drivers d
        LEFT JOIN tab_driver_statuses ds ON ds.id_status = d.id_status
        WHERE d.is_active        = TRUE
          AND d.id_status        = 1
          AND d.license_exp      > CURRENT_DATE
          AND NOT EXISTS (
            SELECT 1 FROM tab_bus_assignments
            WHERE id_driver      = d.id_driver
              AND unassigned_at  IS NULL
          )
        ORDER BY d.name_driver
      `)
      return { success: true, data: result.rows }
    } catch (error) {
      console.error('Error en getAvailableDrivers:', error)
      throw error
    }
  }

  /**
   * Crear nuevo conductor
   * Llama a fun_create_driver v2 (tab_drivers, cédula como PK)
   */
  async createDriver(driverData) {
    try {
      const {
        id_driver,
        name_driver,
        address_driver,
        phone_driver,
        email_driver,
        birth_date,
        gender_driver,
        license_cat,
        license_exp,
        id_eps,
        id_arl,
        blood_type,
        emergency_contact,
        emergency_phone,
        date_entry,
        id_status,
        user_create       = 1
      } = driverData

      const result = await pool.query(
        `SELECT success, msg, error_code, out_driver
         FROM fun_create_driver($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
        [
          id_driver,          // $1  wid_driver
          name_driver,        // $2  wname_driver
          address_driver,     // $3  waddress_driver
          phone_driver,       // $4  wphone_driver
          email_driver,       // $5  wemail_driver
          birth_date,         // $6  wbirth_date
          gender_driver,      // $7  wgender_driver
          license_cat,        // $8  wlicense_cat
          license_exp,        // $9  wlicense_exp
          id_eps,             // $10 wid_eps
          id_arl,             // $11 wid_arl
          blood_type,         // $12 wblood_type
          emergency_contact,  // $13 wemergency_contact
          emergency_phone,    // $14 wemergency_phone
          date_entry,         // $15 wdate_entry
          id_status,          // $16 wid_status
          user_create         // $17 wuser_create
        ]
      )

      const response = result.rows[0]
      if (!response.success) {
        return { success: false, message: response.msg, error_code: response.error_code }
      }

      const driverResult = await this.getDriverById(response.out_driver)
      return { success: true, message: response.msg, data: driverResult.data }

    } catch (error) {
      console.error('Error en createDriver:', error)
      return {
        success: false,
        message: 'Error interno al crear conductor: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      }
    }
  }

  /**
   * Actualizar conductor — llama a fun_update_driver v2 (tab_drivers)
   */
  async updateDriver(idDriver, driverData) {
    try {
      const {
        name_driver,
        address_driver,
        phone_driver,
        email_driver,
        birth_date,
        gender_driver,
        license_cat,
        license_exp,
        id_eps,
        id_arl,
        blood_type,
        emergency_contact,
        emergency_phone,
        date_entry,
        id_status,
        user_update       = 1
      } = driverData

      const result = await pool.query(
        `SELECT success, msg, error_code, out_driver
         FROM fun_update_driver($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
        [
          idDriver,           // $1  wid_driver
          user_update,        // $2  wuser_update
          name_driver,        // $3  wname_driver
          address_driver,     // $4  waddress_driver
          phone_driver,       // $5  wphone_driver
          email_driver,       // $6  wemail_driver
          birth_date,         // $7  wbirth_date
          gender_driver,      // $8  wgender_driver
          license_cat,        // $9  wlicense_cat
          license_exp,        // $10 wlicense_exp
          id_eps,             // $11 wid_eps
          id_arl,             // $12 wid_arl
          blood_type,         // $13 wblood_type
          emergency_contact,  // $14 wemergency_contact
          emergency_phone,    // $15 wemergency_phone
          date_entry,         // $16 wdate_entry
          id_status           // $17 wid_status
        ]
      )

      const response = result.rows[0]
      if (!response.success) {
        return { success: false, message: response.msg, error_code: response.error_code }
      }

      const driverResult = await this.getDriverById(idDriver)
      return { success: true, message: response.msg, data: driverResult.data }

    } catch (error) {
      console.error('Error en updateDriver:', error)
      return {
        success: false,
        message: 'Error interno al actualizar conductor: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      }
    }
  }

  /**
   * Vincular conductor con usuario existente
   * Llama a fun_link_driver_account v1
   */
  async linkAccount(idDriver, idUser, assignedBy = 1) {
    try {
      const result = await pool.query(
        `SELECT success, msg, error_code
         FROM fun_link_driver_account($1, $2, $3)`,
        [idDriver, idUser, assignedBy]
      )
      const response = result.rows[0]
      if (!response.success) {
        return { success: false, message: response.msg, error_code: response.error_code }
      }
      const driverResult = await this.getDriverById(idDriver)
      return { success: true, message: response.msg, data: driverResult.data }
    } catch (error) {
      console.error('Error en linkAccount:', error)
      return { success: false, message: error.message, error_code: 'INTERNAL_ERROR' }
    }
  }

  /**
   * Desvincular cuenta del conductor
   * Llama a fun_unlink_driver_account v1
   */
  async unlinkAccount(idDriver, unlinkedBy = 1) {
    try {
      const result = await pool.query(
        `SELECT success, msg, error_code
         FROM fun_unlink_driver_account($1, $2)`,
        [idDriver, unlinkedBy]
      )
      const response = result.rows[0]
      if (!response.success) {
        return { success: false, message: response.msg, error_code: response.error_code }
      }
      const driverResult = await this.getDriverById(idDriver)
      return { success: true, message: response.msg, data: driverResult.data }
    } catch (error) {
      console.error('Error en unlinkAccount:', error)
      return { success: false, message: error.message, error_code: 'INTERNAL_ERROR' }
    }
  }

  /**
   * Activar/Inactivar conductor (is_active en tab_drivers)
   * Delega en fun_toggle_driver_status v1
   */
  async toggleStatus(idDriver, isActive, userUpdate = 1) {
    try {
      const result = await pool.query(
        `SELECT success, msg, error_code, new_status
         FROM fun_toggle_driver_status($1, $2)`,
        [idDriver, isActive]
      )

      const response = result.rows[0]
      if (!response.success) {
        return { success: false, message: response.msg, error_code: response.error_code }
      }

      const driverResult = await this.getDriverById(idDriver)
      return { success: true, message: response.msg, data: driverResult.data }

    } catch (error) {
      console.error('Error en toggleStatus:', error)
      return {
        success: false,
        message: error.message || 'Error al cambiar estado del conductor',
        error_code: 'INTERNAL_ERROR'
      }
    }
  }


}

export default new DriversService()
