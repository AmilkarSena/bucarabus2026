import pool from './config/database.js'

async function checkFunctions() {
  try {
    const result = await pool.query(`
      SELECT proname, prokind 
      FROM pg_proc 
      WHERE proname LIKE 'fun_%user%'
      ORDER BY proname
    `)
    
    console.log('Funciones encontradas:')
    console.log(result.rows)
    
    // También verificar si las tablas existen
    const tables = await pool.query(`
      SELECT tablename 
      FROM pg_tables 
      WHERE tablename LIKE '%user%'
      ORDER BY tablename
    `)
    
    console.log('\nTablas encontradas:')
    console.log(tables.rows)
    
  } catch (error) {
    console.error('Error:', error.message)
  } finally {
    await pool.end()
  }
}

checkFunctions()
