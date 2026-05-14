import pool from './config/database.js'
import fs from 'fs'

async function migrateToBigint() {
  const client = await pool.connect()
  
  try {
    console.log('🔄 Migrando id_user de INTEGER a BIGINT...\n')
    
    // Ejecutar script de migración
    const migrateSql = fs.readFileSync('./database/migrate_id_user_to_bigint.sql', 'utf8')
    await client.query(migrateSql)
    console.log('✅ Tablas migradas a BIGINT\n')
    
    // Recrear función con BIGINT
    console.log('📝 Recreando fun_create_user con BIGINT...')
    await client.query('DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR)')
    const createUserSql = fs.readFileSync('./database/fun_create_user.sql', 'utf8')
    await client.query(createUserSql)
    console.log('✅ fun_create_user recreada con BIGINT\n')
    
    // Verificar cambios
    console.log('🔍 Verificando tipos de datos...')
    const result = await client.query(`
      SELECT 
        table_name,
        column_name,
        data_type 
      FROM information_schema.columns 
      WHERE column_name LIKE '%id_user%'
        AND table_schema = 'public'
      ORDER BY table_name, column_name
    `)
    
    console.log('📊 Columnas id_user:')
    result.rows.forEach(row => {
      console.log(`   ${row.table_name}.${row.column_name}: ${row.data_type}`)
    })
    
    // Verificar función
    const funcResult = await client.query(`
      SELECT proname, pronargs 
      FROM pg_proc 
      WHERE proname = 'fun_create_user'
    `)
    console.log('\n✅ Función fun_create_user:', funcResult.rows[0])
    
    console.log('\n✨ Migración completada exitosamente!')
    
  } catch (error) {
    console.error('❌ Error durante migración:', error.message)
    console.error(error)
  } finally {
    client.release()
    await pool.end()
  }
}

migrateToBigint()
