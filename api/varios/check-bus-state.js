import pool from '../config/database.js'

try {
  const statuses = await pool.query('SELECT id_status, status_name FROM tab_bus_statuses ORDER BY id_status')
  console.log('tab_bus_statuses:', JSON.stringify(statuses.rows))

  const brands = await pool.query('SELECT id_brand, brand_name FROM tab_brands ORDER BY id_brand LIMIT 5')
  console.log('tab_brands:', JSON.stringify(brands.rows))

  const cols = await pool.query(
    "SELECT column_name, data_type FROM information_schema.columns WHERE table_name = 'tab_buses' AND column_name IN ('brand_bus','id_brand') ORDER BY column_name"
  )
  console.log('tab_buses columns:', JSON.stringify(cols.rows))

  const fns = await pool.query(
    "SELECT proname, pg_get_function_arguments(p.oid) as args FROM pg_proc p WHERE proname = 'fun_create_bus'"
  )
  console.log('fun_create_bus signature:', JSON.stringify(fns.rows))

  process.exit(0)
} catch (e) {
  console.error('ERROR:', e.message)
  process.exit(1)
}
