import pool from './config/database.js'
import fs from 'fs'

async function migrateToIntegerEpoch2025() {
  const client = await pool.connect()
  
  try {
    console.log('🔄 Migrando de BIGINT a INTEGER con epoch 2025-01-01...\n')
    
    // 1. Ejecutar migración de tablas
    console.log('📊 Paso 1: Migrando columnas de BIGINT a INTEGER...')
    const migrateSql = fs.readFileSync('./database/migrate_to_integer_epoch2025.sql', 'utf8')
    await client.query(migrateSql)
    console.log('✅ Tablas migradas a INTEGER\n')
    
    // 2. Recrear fun_create_user
    console.log('📝 Paso 2: Recreando fun_create_user con epoch 2025...')
    await client.query('DROP FUNCTION IF EXISTS fun_create_user(VARCHAR, VARCHAR, VARCHAR, VARCHAR)')
    const createUserSql = fs.readFileSync('./database/fun_create_user.sql', 'utf8')
    await client.query(createUserSql)
    console.log('✅ fun_create_user recreada (INTEGER + epoch 2025)\n')
    
    // 3. Recrear fun_update_user
    console.log('📝 Paso 3: Recreando fun_update_user con INTEGER...')
    await client.query('DROP FUNCTION IF EXISTS fun_update_user(BIGINT, VARCHAR, VARCHAR)')
    await client.query('DROP FUNCTION IF EXISTS fun_update_user(INTEGER, VARCHAR, VARCHAR)')
    const updateUserSql = fs.readFileSync('./database/fun_update_user.sql', 'utf8')
    await client.query(updateUserSql)
    console.log('✅ fun_update_user recreada (INTEGER)\n')
    
    // 4. Verificar cambios
    console.log('🔍 Paso 4: Verificando tipos de datos...')
    const columnsResult = await client.query(`
      SELECT 
        table_name,
        column_name,
        data_type 
      FROM information_schema.columns 
      WHERE column_name LIKE '%id_user%'
        AND table_schema = 'public'
        AND table_name NOT LIKE '%audit%'
      ORDER BY table_name, column_name
    `)
    
    console.log('📊 Columnas id_user:')
    columnsResult.rows.forEach(row => {
      const checkmark = row.data_type === 'integer' ? '✅' : '⚠️ '
      console.log(`   ${checkmark} ${row.table_name}.${row.column_name}: ${row.data_type}`)
    })
    
    // 5. Probar funciones
    console.log('\n🧪 Paso 5: Probando crear usuario...')
    const bcrypt = await import('bcrypt')
    const testEmail = 'test' + Date.now() + '@test.com'
    const testPassword = await bcrypt.hash('test123456', 10)
    
    const testResult = await client.query(`
      SELECT * FROM fun_create_user($1, $2, $3, NULL)
    `, [testEmail, testPassword, 'Test User'])
    
    const user = testResult.rows[0]
    console.log('✅ Usuario de prueba creado:')
    console.log(`   ID: ${user.id_user} (tipo: ${typeof user.id_user === 'string' ? 'string[' + user.id_user.length + ' dígitos]' : typeof user.id_user})`)
    console.log(`   Email: ${user.email}`)
    console.log(`   Rol: ${user.role_name}`)
    console.log(`   ID numérico: ~${Math.floor(user.id_user / 1000000)} millones`)
    
    // Limpiar
    await client.query('DELETE FROM tab_user_roles WHERE id_user = $1', [user.id_user])
    await client.query('DELETE FROM tab_users WHERE id_user = $1', [user.id_user])
    console.log('🗑️  Usuario de prueba eliminado\n')
    
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('✨ MIGRACIÓN COMPLETADA EXITOSAMENTE ✨')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━')
    console.log('📦 Tipo de dato: INTEGER (4 bytes)')
    console.log('📅 Epoch base: 2025-01-01')
    console.log('🎯 IDs generados: ~40 millones hoy')
    console.log('⏰ Vida útil: hasta 2093')
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n')
    
  } catch (error) {
    console.error('❌ Error durante migración:', error.message)
    console.error(error)
  } finally {
    client.release()
    await pool.end()
  }
}

migrateToIntegerEpoch2025()
