/**
 * Script para verificar tablas y datos en la base de datos
 */

import pg from 'pg'
import dotenv from 'dotenv'

dotenv.config()

const { Pool } = pg

const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'db_newBucarabus',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD
})

async function checkDatabase() {
  try {
    console.log('🔍 Conectando a la base de datos...\n')

    // Ver tablas
    const tablesResult = await pool.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = 'public'
      ORDER BY table_name
    `)
    
    console.log('📋 TABLAS EN LA BASE DE DATOS:')
    console.log(tablesResult.rows.map(r => r.table_name).join(', '))
    console.log('')

    // Ver rutas
    try {
      const routesResult = await pool.query('SELECT * FROM tab_routes LIMIT 5')
      console.log('🚦 RUTAS (tab_routes):')
      console.log(JSON.stringify(routesResult.rows, null, 2))
    } catch (e) {
      console.log('⚠️ No se encontró tabla "tab_routes":', e.message)
    }

    // Ver buses
    try {
      const busesResult = await pool.query('SELECT * FROM tab_buses LIMIT 5')
      console.log('\n🚌 BUSES (tab_buses):')
      console.log(JSON.stringify(busesResult.rows, null, 2))
    } catch (e) {
      console.log('⚠️ No se encontró tabla "tab_buses":', e.message)
    }

    // Ver asignaciones
    try {
      const assignResult = await pool.query('SELECT * FROM tab_bus_assignments LIMIT 5')
      console.log('\n📍 ASIGNACIONES (tab_bus_assignments):')
      console.log(JSON.stringify(assignResult.rows, null, 2))
    } catch (e) {
      console.log('⚠️ No se encontró tabla "tab_bus_assignments":', e.message)
    }

  } catch (error) {
    console.error('❌ Error:', error.message)
  } finally {
    await pool.end()
    process.exit(0)
  }
}

checkDatabase()
