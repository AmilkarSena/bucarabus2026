import express from 'express'
import pool from '../config/database.js'
import { verifyToken, requirePermission } from '../middlewares/auth.middleware.js'
import { PERMISSIONS } from '../config/constants.js'

const router = express.Router()

/**
 * GET /api/catalogs/eps - Obtener todas las EPS activas
 */
router.get('/eps', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_eps, name_eps FROM tab_eps WHERE is_active = TRUE ORDER BY name_eps'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener EPS:', error)
    res.status(500).json({ success: false, message: 'Error al obtener EPS' })
  }
})

/**
 * GET /api/catalogs/arl - Obtener todas las ARL activas
 */
router.get('/arl', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_arl, name_arl FROM tab_arl WHERE is_active = TRUE ORDER BY name_arl'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener ARL:', error)
    res.status(500).json({ success: false, message: 'Error al obtener ARL' })
  }
})

/**
 * GET /api/catalogs/trip-statuses - Obtener todos los estados de viaje activos
 * Fuente única de verdad: tab_status_trip
 */
router.get('/trip-statuses', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id_status, status_name, descrip_status, color_hex
       FROM tab_trip_statuses
       WHERE is_active = TRUE
       ORDER BY id_status`
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener estados de viaje:', error)
    res.status(500).json({ success: false, message: 'Error al obtener estados de viaje' })
  }
})

/**
 * GET /api/catalogs/roles - Obtener todos los roles activos
 */
router.get('/roles', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_role, role_name FROM tab_roles WHERE is_active = TRUE ORDER BY id_role'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener roles:', error)
    res.status(500).json({ success: false, message: 'Error al obtener roles' })
  }
})

/**
 * GET /api/catalogs/bus-owners - Obtener todos los propietarios de buses activos
 */
router.get('/bus-owners', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_owner, full_name FROM tab_bus_owners WHERE is_active = TRUE ORDER BY full_name'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener propietarios de buses:', error)
    res.status(500).json({ success: false, message: 'Error al obtener propietarios de buses' })
  }
})

/**
 * GET /api/catalogs/companies - Obtener todas las compañias activas
 */
router.get('/companies', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_company, company_name FROM tab_companies WHERE is_active = TRUE ORDER BY company_name'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener compañías:', error)
    res.status(500).json({ success: false, message: 'Error al obtener compañías' })
  }
})

/**
 * GET /api/catalogs/brands - Obtener todas las marcas de buses activas
 */
router.get('/brands', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_brand, brand_name FROM tab_brands WHERE is_active = TRUE ORDER BY brand_name'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener marcas:', error)
    res.status(500).json({ success: false, message: 'Error al obtener marcas' })
  }
})

/**
 * GET /api/catalogs/points - Obtener todos los puntos de ruta activos
 */
router.get('/points', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT 
        id_point, 
        name_point, 
        descrip_point,
        point_type,
        is_checkpoint,
        is_active,
        ST_Y(location_point::geometry) as lat,
        ST_X(location_point::geometry) as lng
      FROM tab_route_points 
      WHERE is_active = TRUE 
      ORDER BY name_point
    `)
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener puntos de ruta:', error)
    res.status(500).json({ success: false, message: 'Error al obtener puntos de ruta' })
  }
})

/**
 * POST /api/catalogs/points - Crear un nuevo punto de ruta global
 */
router.post('/points', requirePermission(PERMISSIONS.CREATE_STOPS), async (req, res) => {
  try {
    const { name_point, lat, lng, descrip_point, point_type = 1, is_checkpoint = false } = req.body
    
    // Asumimos un ID de usuario por defecto si no viene en el body (simulando auth)
    const user_create = req.user.id_user;

    if (!name_point || lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'Nombre, latitud y longitud son requeridos' })
    }

    const result = await pool.query(
      `SELECT * FROM fun_create_route_point($1, $2, $3, $4, $5, $6, $7)`,
      [name_point, lat, lng, point_type, descrip_point, is_checkpoint, user_create]
    )

    const response = result.rows[0]

    if (!response.success) {
      return res.status(400).json({ success: false, message: response.msg, error_code: response.error_code })
    }

    res.status(201).json({
      success: true,
      message: response.msg,
      data: {
        id_point:      response.out_id_point,
        name_point,
        descrip_point: descrip_point || null,
        lat,
        lng,
        point_type:    point_type ?? 1,
        is_checkpoint: is_checkpoint ?? false,
        is_active:     true
      }
    })
  } catch (error) {
    console.error('Error al crear punto de ruta:', error)
    res.status(500).json({ success: false, message: 'Error interno al crear punto de ruta' })
  }
})

/**
 * GET /api/catalogs/points/admin - Obtener todos los puntos (activos e inactivos)
 */
router.get('/points/admin', requirePermission(PERMISSIONS.VIEW_STOPS), async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        id_point,
        name_point,
        descrip_point,
        point_type,
        is_checkpoint,
        is_active,
        ST_Y(location_point::geometry) as lat,
        ST_X(location_point::geometry) as lng
      FROM tab_route_points
      ORDER BY name_point
    `)
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener puntos de ruta (admin):', error)
    res.status(500).json({ success: false, message: 'Error al obtener puntos de ruta' })
  }
})

/**
 * PUT /api/catalogs/points/:id - Actualizar un punto de ruta
 */
router.put('/points/:id', requirePermission(PERMISSIONS.EDIT_STOPS), async (req, res) => {
  try {
    const id = Number(req.params.id)
    const { name_point, lat, lng, point_type = 1, descrip_point = null, is_checkpoint = false } = req.body
    const user_update = req.user.id_user

    if (!name_point || lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, message: 'Nombre, latitud y longitud son requeridos' })
    }

    const result = await pool.query(
      `SELECT * FROM fun_update_route_point($1, $2, $3, $4, $5, $6, $7, $8)`,
      [id, name_point, lat, lng, point_type, descrip_point, is_checkpoint, user_update]
    )

    const response = result.rows[0]
    if (!response.success) {
      const status = response.error_code === 'ROUTE_POINT_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: response.msg, error_code: response.error_code })
    }

    res.json({
      success: true,
      message: response.msg,
      data: { id_point: response.out_id_point, name_point, descrip_point, lat, lng, point_type, is_checkpoint }
    })
  } catch (error) {
    console.error('Error al actualizar punto de ruta:', error)
    res.status(500).json({ success: false, message: 'Error interno al actualizar punto de ruta' })
  }
})

/**
 * PATCH /api/catalogs/points/:id/toggle - Activar/desactivar un punto de ruta
 */
router.patch('/points/:id/toggle', requirePermission(PERMISSIONS.EDIT_STOPS), async (req, res) => {
  try {
    const id = Number(req.params.id)
    const { is_active } = req.body
    const user_update = req.user.id_user

    if (is_active === undefined) {
      return res.status(400).json({ success: false, message: 'El campo is_active es requerido' })
    }

    const result = await pool.query(
      `SELECT * FROM fun_toggle_route_point($1, $2, $3)`,
      [id, is_active, user_update]
    )

    const response = result.rows[0]
    if (!response.success) {
      const status = response.error_code === 'ROUTE_POINT_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: response.msg, error_code: response.error_code })
    }

    res.json({ success: true, message: response.msg, data: { id_point: response.out_id_point, is_active: response.new_status } })
  } catch (error) {
    console.error('Error al cambiar estado de punto de ruta:', error)
    res.status(500).json({ success: false, message: 'Error interno al cambiar estado' })
  }
})

// =============================================
// EPS - CRUD Admin
// =============================================

router.get('/eps/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_eps, name_eps, is_active FROM tab_eps ORDER BY name_eps'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener EPS:', error)
    res.status(500).json({ success: false, message: 'Error al obtener EPS' })
  }
})

router.post('/eps', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { name_eps } = req.body
    if (!name_eps?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_create_eps($1)', [name_eps])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'EPS_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_eps: row.out_id_eps, name_eps: row.out_name, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear EPS:', error)
    res.status(500).json({ success: false, message: 'Error al crear EPS' })
  }
})

router.put('/eps/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { name_eps } = req.body
    if (!name_eps?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_update_eps($1, $2)', [id, name_eps])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'EPS_NOT_FOUND' ? 404
                   : row.error_code === 'EPS_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_eps: row.out_id_eps, name_eps: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar EPS:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar EPS' })
  }
})

router.patch('/eps/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_eps($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'EPS_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_eps: row.out_id_eps, name_eps: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de EPS:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})

// =============================================
// ARL - CRUD Admin
// =============================================

router.get('/arl/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_arl, name_arl, is_active FROM tab_arl ORDER BY name_arl'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener ARL:', error)
    res.status(500).json({ success: false, message: 'Error al obtener ARL' })
  }
})

router.post('/arl', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { name_arl } = req.body
    if (!name_arl?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_create_arl($1)', [name_arl])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'ARL_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_arl: row.out_id_arl, name_arl: row.out_name, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear ARL:', error)
    res.status(500).json({ success: false, message: 'Error al crear ARL' })
  }
})

router.put('/arl/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { name_arl } = req.body
    if (!name_arl?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_update_arl($1, $2)', [id, name_arl])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'ARL_NOT_FOUND' ? 404
                   : row.error_code === 'ARL_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_arl: row.out_id_arl, name_arl: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar ARL:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar ARL' })
  }
})

router.patch('/arl/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_arl($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'ARL_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_arl: row.out_id_arl, name_arl: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de ARL:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})

// =============================================
// Marcas - CRUD Admin
// =============================================

router.get('/brands/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_brand, brand_name, is_active FROM tab_brands ORDER BY brand_name'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener marcas:', error)
    res.status(500).json({ success: false, message: 'Error al obtener marcas' })
  }
})

router.post('/brands', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { brand_name } = req.body
    if (!brand_name?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_create_brand($1)', [brand_name])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'BRAND_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_brand: row.out_id_brand, brand_name: row.out_name, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear marca:', error)
    res.status(500).json({ success: false, message: 'Error al crear marca' })
  }
})

router.put('/brands/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { brand_name } = req.body
    if (!brand_name?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_update_brand($1, $2)', [id, brand_name])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'BRAND_NOT_FOUND' ? 404
                   : row.error_code === 'BRAND_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_brand: row.out_id_brand, brand_name: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar marca:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar marca' })
  }
})

router.patch('/brands/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_brand($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'BRAND_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_brand: row.out_id_brand, brand_name: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de marca:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})

// =============================================
// Compañías - CRUD Admin
// =============================================

router.get('/companies/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_company, company_name, nit_company, is_active FROM tab_companies ORDER BY company_name'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener compañías:', error)
    res.status(500).json({ success: false, message: 'Error al obtener compañías' })
  }
})

router.post('/companies', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { company_name, nit_company } = req.body
    if (!company_name?.trim() || !nit_company?.trim()) {
      return res.status(400).json({ success: false, message: 'Nombre y NIT son requeridos' })
    }
    const result = await pool.query(
      'SELECT * FROM fun_create_company($1, $2, $3)',
      [company_name.trim(), nit_company.trim(), req.user.id_user]
    )
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'COMPANY_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_company: row.out_id_company, company_name: row.out_company_name, nit_company: row.out_nit_company, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear compañía:', error)
    res.status(500).json({ success: false, message: 'Error al crear compañía' })
  }
})

router.put('/companies/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { company_name } = req.body
    if (!company_name?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre de la compañía es requerido' })
    }
    const result = await pool.query(
      'SELECT * FROM fun_update_company($1, $2, $3)',
      [id, company_name.trim(), req.user.id_user]
    )
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'COMPANY_NOT_FOUND' ? 404
                   : row.error_code === 'COMPANY_UNIQUE_VIOLATION' ? 409
                   : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_company: row.out_id_company, company_name: row.out_company_name, nit_company: row.out_nit_company, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar compañía:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar compañía' })
  }
})

router.patch('/companies/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params

    // Pre-check: bloquear desactivación si hay buses o rutas activos
    const [busesResult, routesResult] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM tab_buses WHERE id_company = $1 AND is_active = TRUE', [id]),
      pool.query('SELECT COUNT(*) FROM tab_routes WHERE id_company = $1 AND is_active = TRUE', [id])
    ])
    const activeBuses = parseInt(busesResult.rows[0].count)
    const activeRoutes = parseInt(routesResult.rows[0].count)

    if (activeBuses > 0) {
      return res.status(409).json({
        success: false,
        message: `No se puede desactivar la compañía: tiene ${activeBuses} bus(es) activo(s) asociado(s).`,
        error_code: 'COMPANY_HAS_ACTIVE_BUSES'
      })
    }
    if (activeRoutes > 0) {
      return res.status(409).json({
        success: false,
        message: `No se puede desactivar la compañía: tiene ${activeRoutes} ruta(s) activa(s) asociada(s).`,
        error_code: 'COMPANY_HAS_ACTIVE_ROUTES'
      })
    }

    const result = await pool.query(
      'SELECT * FROM fun_toggle_company($1, $2)',
      [id, req.user.id_user]
    )
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'COMPANY_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_company: row.out_id_company, company_name: row.out_company_name, nit_company: row.out_nit_company, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de compañía:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})

// =============================================
// Aseguradoras - CRUD Admin
// =============================================

router.get('/insurers/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_insurer, insurer_name, is_active FROM tab_insurers ORDER BY insurer_name'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener aseguradoras:', error)
    res.status(500).json({ success: false, message: 'Error al obtener aseguradoras' })
  }
})

router.post('/insurers', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { insurer_name } = req.body
    if (!insurer_name?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_create_insurer($1)', [insurer_name])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INSURER_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_insurer: row.out_id_insurer, insurer_name: row.out_name, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear aseguradora:', error)
    res.status(500).json({ success: false, message: 'Error al crear aseguradora' })
  }
})

router.put('/insurers/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { insurer_name } = req.body
    if (!insurer_name?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_update_insurer($1, $2)', [id, insurer_name])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INSURER_NOT_FOUND' ? 404
                   : row.error_code === 'INSURER_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_insurer: row.out_id_insurer, insurer_name: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar aseguradora:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar aseguradora' })
  }
})

router.patch('/insurers/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_insurer($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INSURER_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_insurer: row.out_id_insurer, insurer_name: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de aseguradora:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})


// =============================================
// Tipos de Seguros - CRUD Admin
// =============================================

router.get('/insurance-types/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_insurance_type, tag_insurance AS code, name_insurance, descrip_insurance, is_mandatory, is_active FROM tab_insurance_types ORDER BY name_insurance'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener tipos de seguros:', error)
    res.status(500).json({ success: false, message: 'Error al obtener tipos de seguros' })
  }
})

router.post('/insurance-types', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { code, name_insurance, descrip_insurance, is_mandatory } = req.body
    if (!name_insurance?.trim() || !code?.trim()) {
      return res.status(400).json({ success: false, message: 'El código y el nombre son requeridos' })
    }
    if (false) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_create_insurance_type($1, $2, $3, $4)', [code.toUpperCase(), name_insurance, descrip_insurance || null, is_mandatory ?? true])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INSURANCE_TYPE_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_insurance_type: row.out_id_type, code: code.toUpperCase(), name_insurance, descrip_insurance, is_mandatory, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear tipo de seguro:', error)
    res.status(500).json({ success: false, message: 'Error al crear tipo de seguro' })
  }
})

router.put('/insurance-types/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { code, name_insurance, descrip_insurance, is_mandatory } = req.body
    if (!name_insurance?.trim() || !code?.trim()) {
      return res.status(400).json({ success: false, message: 'El código y el nombre son requeridos' })
    }
    if (false) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_update_insurance_type($1, $2, $3, $4, $5)', [id, code.toUpperCase(), name_insurance, descrip_insurance || null, is_mandatory ?? true])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INSURANCE_TYPE_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_insurance_type: row.out_id_type, code: code.toUpperCase(), name_insurance: row.out_name, descrip_insurance, is_mandatory, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar tipo de seguro:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar tipo de seguro' })
  }
})

router.patch('/insurance-types/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_insurance_type($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INSURANCE_TYPE_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_insurance_type: row.out_id_type, name_insurance: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de tipo de seguro:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})

// =============================================
// Tipos de Documentos de Tránsito - CRUD Admin
// =============================================

router.get('/transit-docs/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_doc, tag_transit_doc AS code, name_doc, descrip_doc, is_mandatory, is_active, has_expiration FROM tab_transit_documents ORDER BY name_doc'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener tipos de documentos:', error)
    res.status(500).json({ success: false, message: 'Error al obtener tipos de documentos' })
  }
})

router.post('/transit-docs', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { code, name_doc, descrip_doc, is_mandatory, has_expiration } = req.body
    if (!name_doc?.trim() || !code?.trim()) {
      return res.status(400).json({ success: false, message: 'El código y el nombre son requeridos' })
    }
    if (false) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_create_transit_doc_type($1, $2, $3, $4, $5)', [code.toUpperCase(), name_doc, descrip_doc || null, is_mandatory ?? true, has_expiration ?? true])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'TRANSIT_DOC_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_doc: row.out_id_doc, code: code.toUpperCase(), name_doc, descrip_doc, is_mandatory, has_expiration, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear tipo de documento:', error)
    res.status(500).json({ success: false, message: 'Error al crear tipo de documento' })
  }
})

router.put('/transit-docs/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { code, name_doc, descrip_doc, is_mandatory, has_expiration } = req.body
    if (!name_doc?.trim() || !code?.trim()) {
      return res.status(400).json({ success: false, message: 'El código y el nombre son requeridos' })
    }
    if (false) {
      return res.status(400).json({ success: false, message: 'El nombre es requerido' })
    }
    const result = await pool.query('SELECT * FROM fun_update_transit_doc_type($1, $2, $3, $4, $5, $6)', [id, code.toUpperCase(), name_doc, descrip_doc || null, is_mandatory ?? true, has_expiration ?? true])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'TRANSIT_DOC_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_doc: row.out_id_doc, code: code.toUpperCase(), name_doc: row.out_name, descrip_doc, is_mandatory, has_expiration, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar tipo de documento:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar tipo de documento' })
  }
})

router.patch('/transit-docs/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_transit_doc_type($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'TRANSIT_DOC_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_doc: row.out_id_doc, name_doc: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de tipo de documento:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})


// =============================================
// Tipos de Incidentes
// =============================================
router.get('/incident-types', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_incident, name_incident, tag_incident FROM tab_incident_types WHERE is_active = TRUE ORDER BY id_incident'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener tipos de incidentes:', error)
    res.status(500).json({ success: false, message: 'Error al obtener tipos de incidentes' })
  }
})

// CRUD Admin
router.get('/incident-types/admin', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id_incident, name_incident, tag_incident, is_active FROM tab_incident_types ORDER BY id_incident'
    )
    res.json({ success: true, data: result.rows })
  } catch (error) {
    console.error('Error al obtener tipos de incidentes (admin):', error)
    res.status(500).json({ success: false, message: 'Error al obtener tipos de incidentes' })
  }
})

router.post('/incident-types', requirePermission(PERMISSIONS.CREATE_CATALOGS), async (req, res) => {
  try {
    const { name_incident, tag_incident } = req.body
    if (!name_incident?.trim() || !tag_incident?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre y el tag son requeridos' })
    }
    const result = await pool.query('SELECT * FROM fun_create_incident_type($1, $2)', [name_incident, tag_incident])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INCIDENT_TYPE_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.status(201).json({
      success: true,
      data: { id_incident: row.out_id_type, name_incident: row.out_name, tag_incident: row.out_tag, is_active: true }
    })
  } catch (error) {
    console.error('Error al crear tipo de incidente:', error)
    res.status(500).json({ success: false, message: 'Error al crear tipo de incidente' })
  }
})

router.put('/incident-types/:id', requirePermission(PERMISSIONS.EDIT_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const { name_incident, tag_incident } = req.body
    if (!name_incident?.trim() || !tag_incident?.trim()) {
      return res.status(400).json({ success: false, message: 'El nombre y el tag son requeridos' })
    }
    const result = await pool.query('SELECT * FROM fun_update_incident_type($1, $2, $3)', [id, name_incident, tag_incident])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INCIDENT_TYPE_NOT_FOUND' ? 404
                   : row.error_code === 'INCIDENT_TYPE_UNIQUE_VIOLATION' ? 409 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_incident: row.out_id_type, name_incident: row.out_name, tag_incident: row.out_tag, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al actualizar tipo de incidente:', error)
    res.status(500).json({ success: false, message: 'Error al actualizar tipo de incidente' })
  }
})

router.patch('/incident-types/:id/toggle', requirePermission(PERMISSIONS.TOGGLE_CATALOGS), async (req, res) => {
  try {
    const { id } = req.params
    const result = await pool.query('SELECT * FROM fun_toggle_incident_type($1)', [id])
    const row = result.rows[0]
    if (!row.success) {
      const status = row.error_code === 'INCIDENT_TYPE_NOT_FOUND' ? 404 : 400
      return res.status(status).json({ success: false, message: row.msg, error_code: row.error_code })
    }
    res.json({
      success: true,
      data: { id_incident: row.out_id_type, name_incident: row.out_name, is_active: row.out_is_active }
    })
  } catch (error) {
    console.error('Error al cambiar estado de tipo de incidente:', error)
    res.status(500).json({ success: false, message: 'Error al cambiar estado' })
  }
})

export default router
