import pg from 'pg'
import dotenv from 'dotenv'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

dotenv.config()

const __dirname = dirname(fileURLToPath(import.meta.url))

const { Pool } = pg
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'db_bucarabus',
  user: 'postgres',
  password: process.env.DB_POSTGRES_PASSWORD || ''
})

const sql = readFileSync(
  join(__dirname, '../database/functions_v2/fun_toggle_user_status_v1.sql'),
  'utf8'
)

try {
  await pool.query(sql)
  console.log('✅ fun_toggle_user_status creada correctamente')

  // Verificar
  const r = await pool.query(`SELECT proname FROM pg_proc WHERE proname = 'fun_toggle_user_status'`)
  console.log('✅ Verificada en DB:', r.rows[0]?.proname)
} catch (e) {
  console.error('❌ Error:', e.message)
} finally {
  await pool.end()
  process.exit(0)
}
