import pool from '../config/database.js'
const SYSTEM_USER_ID = -1;
class BusesService {

  /**
   * Helper privado: resuelve id_bus a partir de plate_number.
   * Lanza error si la placa no existe.
   * @param {string} plateNumber
   * @param {object} [client] - cliente pg opcional (para transacciones)
   * @returns {Promise<number>} id_bus
   */
  async _getIdBusByPlate(plateNumber, client = pool) {
    const result = await client.query(
      `SELECT id_bus FROM tab_buses WHERE plate_number = $1`,
      [plateNumber.toUpperCase()]
    );
    if (result.rows.length === 0) {
      const err = new Error(`Bus no encontrado con placa: ${plateNumber.toUpperCase()}`);
      err.code = 'BUS_NOT_FOUND';
      throw err;
    }
    return result.rows[0].id_bus;
  }

  /**
   * Obtener todos los buses
   * @param {boolean} onlyActive - Si true, solo retorna buses activos
   */
  async getAllBuses(onlyActive = false) {
    try {
      let query = `
        SELECT
          b.id_bus,
          b.plate_number,
          b.amb_code,
          b.code_internal,
          b.id_company,
          c.company_name,
          b.id_brand,
          br.brand_name,
          b.model_name,
          b.model_year,
          b.capacity_bus,
          b.chassis_number,
          b.color_bus,
          b.color_app,
          b.photo_url,
          b.gps_device_id,
          b.id_owner,
          o.full_name AS owner_name,
          b.id_status,
          s.status_name,
          b.is_active,
          b.created_at,
          b.updated_at,
          b.user_create,
          b.user_update,
          a.id_driver            AS assigned_driver,
          a.assigned_at          AS assignment_date,
          ins_cov.insurance_coverage,
          doc_cov.transit_doc_coverage
        FROM tab_buses b
        LEFT JOIN tab_companies       c ON c.id_company  = b.id_company
        LEFT JOIN tab_brands          br ON br.id_brand  = b.id_brand
        LEFT JOIN tab_bus_owners      o ON o.id_owner    = b.id_owner
        LEFT JOIN tab_bus_statuses    s ON s.id_status   = b.id_status
        LEFT JOIN tab_bus_assignments a ON a.id_bus      = b.id_bus
                                       AND a.unassigned_at IS NULL
        LEFT JOIN LATERAL (
          SELECT COALESCE(
            json_agg(
              json_build_object('type', sub.t, 'name', sub.n, 'status', sub.s)
              ORDER BY sub.t
            ),
            '[]'::json
          ) AS insurance_coverage
          FROM (
            SELECT
              it.tag_insurance AS t,
              it.name_insurance         AS n,
              CASE
                WHEN best.end_date_insu IS NULL                  THEN 'missing'
                WHEN best.end_date_insu < CURRENT_DATE           THEN 'expired'
                WHEN best.end_date_insu - CURRENT_DATE <= 30     THEN 'expiring'
                ELSE 'ok'
              END AS s
            FROM tab_insurance_types it
            LEFT JOIN LATERAL (
              SELECT bi.end_date_insu
              FROM tab_bus_insurance bi
              WHERE bi.id_bus            = b.id_bus
                AND bi.id_insurance_type = it.id_insurance_type
              LIMIT 1
            ) best ON true
            WHERE it.is_active    = TRUE
              AND it.is_mandatory = TRUE
          ) sub
        ) ins_cov ON true
        LEFT JOIN LATERAL (
          SELECT COALESCE(
            json_agg(
              json_build_object('type', sub.t, 'name', sub.n, 'status', sub.s)
              ORDER BY sub.t
            ),
            '[]'::json
          ) AS transit_doc_coverage
          FROM (
            SELECT
              td.tag_transit_doc   AS t,
              td.name_doc AS n,
              CASE
                WHEN best.end_date IS NULL                   THEN 'missing'
                WHEN best.end_date < CURRENT_DATE            THEN 'expired'
                WHEN best.end_date - CURRENT_DATE <= 30      THEN 'expiring'
                ELSE 'ok'
              END AS s
            FROM tab_transit_documents td
            LEFT JOIN LATERAL (
              SELECT btd.end_date
              FROM tab_bus_transit_docs btd
              WHERE btd.id_bus = b.id_bus
                AND btd.id_doc = td.id_doc
              ORDER BY btd.end_date DESC
              LIMIT 1
            ) best ON true
            WHERE td.is_active    = TRUE
              AND td.is_mandatory = TRUE
          ) sub
        ) doc_cov ON true
      `;

      if (onlyActive) {
        query += ' WHERE b.is_active = TRUE';
      }

      query += ' ORDER BY b.plate_number';
      
      const result = await pool.query(query);
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getAllBuses:', error);
      throw error;
    }
  }

  /**
   * Obtener bus por placa
   * @param {string} plateNumber - Placa del bus
   */
  async getBusByPlate(plateNumber) {
    try {
      const result = await pool.query(
        `SELECT
          b.id_bus,
          b.plate_number,
          b.amb_code,
          b.code_internal,
          b.id_company,
          c.company_name,
          b.id_brand,
          br.brand_name,
          b.model_name,
          b.model_year,
          b.capacity_bus,
          b.chassis_number,
          b.color_bus,
          b.color_app,
          b.photo_url,
          b.gps_device_id,
          b.id_owner,
          o.full_name AS owner_name,
          b.id_status,
          s.status_name,
          b.is_active,
          b.created_at,
          b.updated_at,
          b.user_create,
          b.user_update,
          a.id_driver   AS assigned_driver,
          a.assigned_at AS assignment_date
        FROM tab_buses b
        LEFT JOIN tab_companies       c ON c.id_company   = b.id_company
        LEFT JOIN tab_brands          br ON br.id_brand   = b.id_brand
        LEFT JOIN tab_bus_owners      o ON o.id_owner     = b.id_owner
        LEFT JOIN tab_bus_statuses    s ON s.id_status    = b.id_status
        LEFT JOIN tab_bus_assignments a ON a.id_bus       = b.id_bus
                                       AND a.unassigned_at IS NULL
        WHERE b.plate_number = $1`,
        [plateNumber.toUpperCase()]
      );
      
      if (result.rows.length === 0) {
        return {
          success: false,
          message: 'Bus no encontrado'
        };
      }

      return {
        success: true,
        data: result.rows[0]
      };
    } catch (error) {
      console.error('Error en getBusByPlate:', error);
      throw error;
    }
  }

  /**
   * Obtener buses disponibles (activos y sin conductor asignado)
   */
  async getAvailableBuses() {
    try {
      // Buses disponibles: activos, en estado 'disponible' (id_status=1) y sin conductor asignado
      const result = await pool.query(
        `SELECT
          b.id_bus,
          b.plate_number,
          b.amb_code,
          b.code_internal,
          b.id_company,
          c.company_name,
          b.id_brand,
          br.brand_name,
          b.model_name,
          b.model_year,
          b.capacity_bus,
          b.color_bus,
          b.color_app,
          b.gps_device_id,
          b.id_owner,
          o.full_name AS owner_name,
          b.id_status,
          s.status_name
        FROM tab_buses b
        LEFT JOIN tab_companies    c ON c.id_company  = b.id_company
        LEFT JOIN tab_brands       br ON br.id_brand  = b.id_brand
        LEFT JOIN tab_bus_owners   o ON o.id_owner    = b.id_owner
        LEFT JOIN tab_bus_statuses s ON s.id_status   = b.id_status
        WHERE b.is_active = TRUE
          AND b.id_status = 1
          AND NOT EXISTS (
            SELECT 1 FROM tab_bus_assignments
            WHERE id_bus = b.id_bus
              AND unassigned_at IS NULL
          )
        ORDER BY b.plate_number`
      );
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getAvailableBuses:', error);
      throw error;
    }
  }

  /**
   * Obtener buses y rutas activas para pasajeros (endpoint público minimalista)
   * Retorna solo campos necesarios para la app de pasajero.
   */
  async getPassengerActiveBuses() {
    try {
      const result = await pool.query(
        `SELECT
           b.plate_number,
           b.amb_code,
           b.code_internal,
           t.id_route,
           r.name_route,
           r.color_route,
           t.id_status AS status_trip
         FROM tab_trips t
         JOIN tab_buses b ON b.id_bus = t.id_bus
         JOIN tab_routes r ON r.id_route = t.id_route
         WHERE t.trip_date = CURRENT_DATE
           AND t.is_active = TRUE
           AND t.id_status IN (2, 3)
         ORDER BY t.start_time ASC`
      );

      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getPassengerActiveBuses:', error);
      throw error;
    }
  }

  /**
   * Crear nuevo bus
   * Llama a fun_create_bus (v2) que delega validación a fun_validate_bus_data.
   *
   * Parámetros obligatorios en busData:
   *   plate_number, amb_code, code_internal, id_company,
   *   model_year, capacity_bus, color_bus, id_owner, user_create
   *
   * Parámetros opcionales (defaults en la función PostgreSQL):
   *   brand_bus, model_name, chassis_number, photo_url, gps_device_id
   */
  async createBus(busData) {
    try {
      const {
        plate_number,
        amb_code,
        code_internal,
        id_company,
        model_year,
        capacity_bus,
        color_bus,
        id_owner,
        user_create,
        id_brand      = null,
        model_name    = 'SA',
        chassis_number = 'SA',
        photo_url     = null,
        gps_device_id = null,
        color_app     = '#CCCCCC'
      } = busData;

      // Llamada posicional: los 15 parámetros en el mismo orden que la firma de fun_create_bus
      const result = await pool.query(
        `SELECT success, msg, error_code, out_id_bus, out_plate
         FROM fun_create_bus($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          plate_number,    // $1  wplate_number
          amb_code,        // $2  wamb_code
          code_internal,   // $3  wcode_internal
          id_company,      // $4  wid_company
          model_year,      // $5  wmodel_year
          capacity_bus,    // $6  wcapacity_bus
          color_bus,       // $7  wcolor_bus
          id_owner,        // $8  wid_owner
          user_create,     // $9  wuser_create
          id_brand,        // $10 wid_brand
          model_name,      // $11 wmodel_name
          chassis_number,  // $12 wchassis_number
          photo_url,       // $13 wphoto_url
          gps_device_id,   // $14 wgps_device_id
          color_app        // $15 wcolor_app
        ]
      );

      const response = result.rows[0];
      // response contiene: { success, msg, error_code, out_id_bus, out_plate }

      if (!response.success) {
        let friendlyMessage = response.msg;
        if (response.error_code === 'BUS_UNIQUE_VIOLATION') {
          if (friendlyMessage.includes('uq_buses_plate_number') || friendlyMessage.includes('plate_number')) {
            friendlyMessage = 'Ya existe un bus registrado con esta placa.';
          } else if (friendlyMessage.includes('uq_buses_amb_code') || friendlyMessage.includes('amb_code')) {
            friendlyMessage = 'El código AMB ya está en uso por otro bus.';
          } else if (friendlyMessage.includes('code_internal')) {
            friendlyMessage = 'El código interno ya está en uso por otro bus.';
          } else if (friendlyMessage.includes('gps_device_id')) {
            friendlyMessage = 'El ID de dispositivo GPS ya está registrado en otro bus.';
          } else {
            friendlyMessage = 'Un campo único ya está en uso (Placa, AMB, Código Interno o GPS).';
          }
        }
        return {
          success: false,
          message: friendlyMessage,
          error_code: response.error_code
        };
      }

      return {
        success: true,
        message: response.msg,
        data: { id_bus: response.out_id_bus, plate_number: response.out_plate }
      };
    } catch (error) {
      console.error('Error en createBus:', error);
      return {
        success: false,
        message: 'Error interno al crear bus: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Actualizar bus existente
   */
  async updateBus(plateNumber, busData) {                     
    try {
      const {
        amb_code,
        code_internal,
        id_company,
        model_year,
        capacity_bus,
        color_bus,
        id_owner,
        user_update,
        id_brand       = null,
        model_name     = 'SA',
        chassis_number = 'SA',
        photo_url      = null,
        gps_device_id  = null,
        color_app      = '#CCCCCC'
      } = busData;

      const result = await pool.query(
        `SELECT success, msg, error_code, out_id_bus, out_plate
         FROM fun_update_bus($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
        [
          plateNumber.toUpperCase(),
          amb_code,
          code_internal,
          id_company,
          model_year,
          capacity_bus,
          color_bus,
          id_owner,
          user_update,
          id_brand,
          model_name,
          chassis_number,
          photo_url,
          gps_device_id,
          color_app
        ]
      );

      const response = result.rows[0];

      if (!response.success) {
        let friendlyMessage = response.msg;
        if (response.error_code === 'BUS_UNIQUE_VIOLATION') {
          if (friendlyMessage.includes('uq_buses_plate_number') || friendlyMessage.includes('plate_number')) {
            friendlyMessage = 'Ya existe un bus registrado con esta placa.';
          } else if (friendlyMessage.includes('uq_buses_amb_code') || friendlyMessage.includes('amb_code')) {
            friendlyMessage = 'El código AMB ya está en uso por otro bus.';
          } else if (friendlyMessage.includes('code_internal')) {
            friendlyMessage = 'El código interno ya está en uso por otro bus.';
          } else if (friendlyMessage.includes('gps_device_id')) {
            friendlyMessage = 'El ID de dispositivo GPS ya está registrado en otro bus.';
          } else {
            friendlyMessage = 'Un campo único ya está en uso (Placa, AMB, Código Interno o GPS).';
          }
        }
        return {
          success: false,
          message: friendlyMessage,
          error_code: response.error_code
        };
      }

      const busResult = await this.getBusByPlate(plateNumber);
      return {
        success: true,
        message: response.msg,
        data: busResult.data
      };
    } catch (error) {
      console.error('Error en updateBus:', error);
      return {
        success: false,
        message: 'Error interno al actualizar bus: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Cambiar estado del bus (activar/desactivar)
   */
  async toggleBusStatus(plateNumber, isActive, userUpdate) {
    try {
      // VALIDACIONES DE NEGOCIO: Evitar desactivar buses en uso
      if (isActive === false) {
        const validation = await pool.query(
          `SELECT 
             b.id_bus,
             EXISTS(SELECT 1 FROM tab_bus_assignments WHERE id_bus = b.id_bus AND unassigned_at IS NULL) as has_assignment,
             EXISTS(SELECT 1 FROM tab_trips WHERE id_bus = b.id_bus AND id_status IN (2, 3) AND is_active = TRUE) as has_active_trips
           FROM tab_buses b 
           WHERE b.plate_number = $1`,
          [plateNumber.toUpperCase()]
        );
        
        if (validation.rows.length > 0) {
          const { has_assignment, has_active_trips } = validation.rows[0];

          // 1. Validar conductor asignado
          if (has_assignment) {
            return {
              success: false,
              message: 'No se puede desactivar el bus porque tiene un conductor asignado actualmente.',
              error_code: 'BUS_IN_USE'
            };
          }

          // 2. Validar viajes activos o asignados (id_status = 2 o 3)
          if (has_active_trips) {
            return {
              success: false,
              message: 'No se puede desactivar el bus porque tiene un viaje en estado asignado o activo.',
              error_code: 'BUS_IN_USE'
            };
          }
        }
      }

      const result = await pool.query(
        `SELECT success, msg, error_code, out_id_bus, new_status
         FROM fun_toggle_bus_status($1, $2, $3)`,
        [plateNumber.toUpperCase(), isActive, userUpdate]
      );

      const response = result.rows[0];
      
      // Si fue exitoso, obtener el bus actualizado
      if (response.success) {
        const busResult = await this.getBusByPlate(plateNumber);
        return {
          success: true,
          message: response.msg,
          data: busResult.data
        };
      }
      
      return {
        success: response.success,
        message: response.msg,
        error_code: response.error_code
      };
    } catch (error) {
      console.error('Error en toggleBusStatus:', error);
      return {
        success: false,
        message: 'Error interno al cambiar estado del bus: ' + error.message,
        error_code: 'INTERNAL_ERROR'
      };
    }
  }

  /**
   * Obtener buses con documentos próximos a vencer
   * @param {number} days - Número de días para considerar "próximo a vencer"
   */
  async getBusesWithExpiringDocs(days = 30) {
    try {
      const result = await pool.query(
        `SELECT
          b.id_bus,
          b.plate_number,
          b.amb_code,
          b.code_internal,
          bi.id_insurance_type AS insurance_type,
          it.name_insurance,
          bi.end_date_insu,
          (bi.end_date_insu - CURRENT_DATE) AS days_remaining
        FROM tab_bus_insurance bi
        INNER JOIN tab_buses           b  ON b.id_bus             = bi.id_bus
        INNER JOIN tab_insurance_types it ON it.id_insurance_type = bi.id_insurance_type
        WHERE b.is_active             = TRUE
          AND CURRENT_DATE BETWEEN bi.start_date_insu AND bi.end_date_insu
          AND bi.end_date_insu       <= CURRENT_DATE + ($1 * INTERVAL '1 day')
        ORDER BY bi.end_date_insu ASC`,
        [days]
      );
      
      return {
        success: true,
        data: result.rows
      };
    } catch (error) {
      console.error('Error en getBusesWithExpiringDocs:', error);
      throw error;
    }
  }

  /**
   * Obtener estadísticas de buses
   */
  async getBusStats() {
    try {
      const result = await pool.query(`
        SELECT 
          COUNT(*) as total,
          COUNT(*) FILTER (WHERE is_active = TRUE) as active,
          COUNT(*) FILTER (WHERE is_active = FALSE) as inactive,
          COUNT(*) FILTER (WHERE is_active = TRUE AND id_status = 1) as available,
          COALESCE(SUM(capacity_bus) FILTER (WHERE is_active = TRUE), 0) as total_capacity
        FROM tab_buses
      `);
      
      return {
        success: true,
        data: result.rows[0]
      };
    } catch (error) {
      console.error('Error en getBusStats:', error);
      throw error;
    }
  }

  // ─── Catálogos de seguros y documentos ───────────────────────────────────

  async getActiveInsuranceTypes() {
    try {
      const result = await pool.query(
        `SELECT id_insurance_type, name_insurance, descrip_insurance, is_mandatory
         FROM tab_insurance_types
         WHERE is_active = TRUE
         ORDER BY name_insurance`
      );
      return { success: true, data: result.rows };
    } catch (error) {
      console.error('Error en getActiveInsuranceTypes:', error);
      throw error;
    }
  }

  async getActiveInsurers() {
    try {
      const result = await pool.query(
        `SELECT id_insurer, insurer_name
         FROM tab_insurers
         WHERE is_active = TRUE
         ORDER BY insurer_name`
      );
      return { success: true, data: result.rows };
    } catch (error) {
      console.error('Error en getActiveInsurers:', error);
      throw error;
    }
  }

  async getActiveTransitDocTypes() {
    try {
      const result = await pool.query(
        `SELECT id_doc, name_doc, descrip_doc, is_mandatory
         FROM tab_transit_documents
         WHERE is_active = TRUE
         ORDER BY name_doc`
      );
      return { success: true, data: result.rows };
    } catch (error) {
      console.error('Error en getActiveTransitDocTypes:', error);
      throw error;
    }
  }

  // ─── Seguros por bus ─────────────────────────────────────────────────────────

  async getBusInsurance(plateNumber) {
    try {
      const idBus = await this._getIdBusByPlate(plateNumber);
      const result = await pool.query(
        `SELECT
           bi.id_insurance,
           bi.id_insurance_type,
           it.name_insurance,
           bi.id_insurer,
           ins.insurer_name,
           bi.start_date_insu,
           bi.end_date_insu,
           bi.doc_url,
           bi.created_at,
           CASE
             WHEN bi.end_date_insu < CURRENT_DATE         THEN 'expired'
             WHEN (bi.end_date_insu - CURRENT_DATE) <= 30 THEN 'expiring'
             ELSE 'active'
           END AS vigency_status,
           (bi.end_date_insu - CURRENT_DATE) AS days_remaining
         FROM tab_bus_insurance bi
         JOIN tab_insurance_types it  ON it.id_insurance_type = bi.id_insurance_type
         JOIN tab_insurers        ins ON ins.id_insurer       = bi.id_insurer
         WHERE bi.id_bus = $1
         ORDER BY it.name_insurance`,
        [idBus]
      );
      return { success: true, data: result.rows };
    } catch (error) {
      if (error.code === 'BUS_NOT_FOUND') {
        return { success: false, message: error.message, error_code: 'BUS_NOT_FOUND' };
      }
      console.error('Error en getBusInsurance:', error);
      throw error;
    }
  }

  /**
   * Registra o reemplaza la póliza vigente de un tipo para un bus.
   * Hace DELETE del registro anterior (si existe) + INSERT del nuevo,
   * ambos dentro de una transacción — el trigger de auditoría captura ambos eventos.
   */
  async addBusInsurance(plateNumber, data, userCreate) {
    const client = await pool.connect();
    try {
      const { id_insurance, id_insurance_type, id_insurer, start_date_insu, end_date_insu, doc_url = null } = data;

      // Resolver id_bus dentro de la transacción
      const idBus = await this._getIdBusByPlate(plateNumber, client);

      await client.query('BEGIN');
      await client.query(
        `DELETE FROM tab_bus_insurance
         WHERE id_bus = $1 AND id_insurance_type = $2`,
        [idBus, id_insurance_type]
      );
      await client.query(
        `INSERT INTO tab_bus_insurance
           (id_bus, id_insurance_type, id_insurance, id_insurer, start_date_insu, end_date_insu, doc_url, user_create)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [idBus, id_insurance_type, id_insurance, id_insurer, start_date_insu, end_date_insu, doc_url, userCreate]
      );
      await client.query('COMMIT');
      return { success: true, message: 'Póliza registrada correctamente' };
    } catch (error) {
      await client.query('ROLLBACK');
      if (error.code === 'BUS_NOT_FOUND') {
        return { success: false, message: error.message, error_code: 'BUS_NOT_FOUND' };
      }
      if (error.code === '23505') {
        return { success: false, message: `El número de póliza '${data.id_insurance}' ya está registrado en otro bus.` };
      }
      console.error('Error en addBusInsurance:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async updateInsuranceDocUrl(plateNumber, insuranceType, docUrl, userUpdate) {
    try {
      const idBus = await this._getIdBusByPlate(plateNumber);
      const result = await pool.query(
        `UPDATE tab_bus_insurance
         SET doc_url = $3, updated_at = NOW(), user_update = $4
         WHERE id_bus = $1 AND id_insurance_type = $2
         RETURNING id_insurance_type`,
        [idBus, insuranceType, docUrl, userUpdate]
      );
      if (result.rowCount === 0) {
        return { success: false, message: 'Póliza no encontrada' };
      }
      return { success: true, message: 'URL del documento actualizada' };
    } catch (error) {
      if (error.code === 'BUS_NOT_FOUND') {
        return { success: false, message: error.message, error_code: 'BUS_NOT_FOUND' };
      }
      console.error('Error en updateInsuranceDocUrl:', error);
      throw error;
    }
  }

  // ─── Documentos de tránsito por bus ──────────────────────────────────────

  async getBusTransitDocs(plateNumber) {
    try {
      const idBus = await this._getIdBusByPlate(plateNumber);
      const result = await pool.query(
        `SELECT
           btd.id_doc,
           td.name_doc,
           btd.doc_number,
           btd.init_date,
           btd.end_date,
           btd.doc_url,
           btd.created_at,
           CASE
             WHEN btd.end_date < CURRENT_DATE         THEN 'expired'
             WHEN (btd.end_date - CURRENT_DATE) <= 30 THEN 'expiring'
             ELSE 'active'
           END AS vigency_status,
           (btd.end_date - CURRENT_DATE) AS days_remaining
         FROM tab_bus_transit_docs btd
         JOIN tab_transit_documents td ON td.id_doc = btd.id_doc
         WHERE btd.id_bus = $1
         ORDER BY td.name_doc`,
        [idBus]
      );
      return { success: true, data: result.rows };
    } catch (error) {
      if (error.code === 'BUS_NOT_FOUND') {
        return { success: false, message: error.message, error_code: 'BUS_NOT_FOUND' };
      }
      console.error('Error en getBusTransitDocs:', error);
      throw error;
    }
  }

  /**
   * Registra o reemplaza el documento vigente de un tipo para un bus.
   * DELETE del registro anterior (si existe) + INSERT del nuevo, en transacción.
   */
  async addBusTransitDoc(plateNumber, data, userCreate) {
    const client = await pool.connect();
    try {
      const { id_doc, doc_number, init_date, end_date, doc_url = null } = data;
      const safeInitDate = init_date ? init_date : null;
      const safeEndDate = end_date ? end_date : null;

      // Resolver id_bus dentro de la transacción
      const idBus = await this._getIdBusByPlate(plateNumber, client);

      await client.query('BEGIN');
      await client.query(
        `DELETE FROM tab_bus_transit_docs
         WHERE id_doc = $1 AND id_bus = $2`,
        [id_doc, idBus]
      );
      await client.query(
        `INSERT INTO tab_bus_transit_docs
           (id_doc, id_bus, doc_number, init_date, end_date, doc_url, user_create)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [id_doc, idBus, doc_number, safeInitDate, safeEndDate, doc_url, userCreate]
      );
      await client.query('COMMIT');
      return { success: true, message: 'Documento registrado correctamente' };
    } catch (error) {
      await client.query('ROLLBACK');
      if (error.code === 'BUS_NOT_FOUND') {
        return { success: false, message: error.message, error_code: 'BUS_NOT_FOUND' };
      }
      console.error('Error en addBusTransitDoc:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  async updateTransitDocUrl(plateNumber, idDoc, docUrl, userUpdate) {
    try {
      const idBus = await this._getIdBusByPlate(plateNumber);
      const result = await pool.query(
        `UPDATE tab_bus_transit_docs
         SET doc_url = $3, updated_at = NOW(), user_update = $4
         WHERE id_doc = $1 AND id_bus = $2
         RETURNING id_doc`,
        [idDoc, idBus, docUrl, userUpdate]
      );
      if (result.rowCount === 0) {
        return { success: false, message: 'Documento no encontrado' };
      }
      return { success: true, message: 'URL del documento actualizada' };
    } catch (error) {
      if (error.code === 'BUS_NOT_FOUND') {
        return { success: false, message: error.message, error_code: 'BUS_NOT_FOUND' };
      }
      console.error('Error en updateTransitDocUrl:', error);
      throw error;
    }
  }
}

export default new BusesService();
