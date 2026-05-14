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
  join(__dirname, '../database/functions_v2/fun_manage_roles_v1.sql'),
  'utf8'
)

try {
  await pool.query(sql)
  console.log('✅ fun_assign_role y fun_remove_role creadas correctamente')

  const r = await pool.query(`
    SELECT proname FROM pg_proc 
    WHERE proname IN ('fun_assign_role', 'fun_remove_role')
    ORDER BY proname
  `)
  console.log('✅ Verificadas en DB:', r.rows.map(r => r.proname).join(', '))
} catch (e) {
  console.error('❌ Error:', e.message)
} finally {
  await pool.end()
  process.exit(0)
}
