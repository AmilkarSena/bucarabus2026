import pool from './config/database.js'
import fs from 'fs'

async function recreateFunctions() {
  const client = await pool.connect()
  
  try {
    console.log('🗑️  Eliminando funciones duplicadas...')
    
    // Eliminar todas las versiones de fun_create_user
    await client.query(`DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR)`)
    await client.query(`DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR)`)
    console.log('✅ fun_create_user eliminada')
    
    // Eliminar todas las versiones de fun_update_user
    await client.query(`DROP FUNCTION IF EXISTS fun_update_user(INTEGER, VARCHAR, VARCHAR)`)
    await client.query(`DROP FUNCTION IF EXISTS fun_update_user(INTEGER, VARCHAR)`)
    await client.query(`DROP FUNCTION IF EXISTS fun_update_user(INTEGER)`)
    console.log('✅ fun_update_user eliminada')
    
    // Verificar funciones restantes
    const remaining = await client.query(`
      SELECT proname, prokind, pronargs 
      FROM pg_proc 
      WHERE proname LIKE 'fun_%user%'
      ORDER BY proname
    `)
    console.log('\n📋 Funciones restantes:', remaining.rows)
    
    console.log('\n📝 Creando fun_create_user...')
    const createUserSQL = fs.readFileSync('./database/fun_create_user.sql', 'utf8')
    await client.query(createUserSQL)
    console.log('✅ fun_create_user creada')
    
    console.log('\n📝 Creando fun_update_user...')
    const updateUserSQL = fs.readFileSync('./database/fun_update_user.sql', 'utf8')
    await client.query(updateUserSQL)
    console.log('✅ fun_update_user creada')
    
    // Verificar funciones creadas
    const final = await client.query(`
      SELECT proname, prokind, pronargs 
      FROM pg_proc 
      WHERE proname IN ('fun_create_user', 'fun_update_user')
      ORDER BY proname
    `)
    console.log('\n✨ Funciones creadas exitosamente:')
    console.log(final.rows)
    
  } catch (error) {
    console.error('❌ Error:', error.message)
    console.error(error)
  } finally {
    client.release()
    await pool.end()
  }
}

recreateFunctions()
