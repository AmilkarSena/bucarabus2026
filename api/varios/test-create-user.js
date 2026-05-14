import pool from './config/database.js'

async function checkFunction() {
  const client = await pool.connect()
  
  try {
    // Verificar funciones
    const funcs = await client.query(`
      SELECT 
        proname, 
        prokind, 
        pronargs,
        pg_get_functiondef(oid) as definition
      FROM pg_proc 
      WHERE proname = 'fun_create_user'
    `)
    
    console.log(`✅ Funciones fun_create_user encontradas: ${funcs.rows.length}\n`)
    
    if (funcs.rows.length > 1) {
      console.log('⚠️  ADVERTENCIA: Función duplicada!')
      funcs.rows.forEach((f, i) => {
        console.log(`\n--- Función ${i+1} ---`)
        console.log(`Argumentos: ${f.pronargs}`)
      })
    } else if (funcs.rows.length === 1) {
      console.log('Definición de la función:')
      console.log(funcs.rows[0].definition.substring(0, 500) + '...\n')
    }
    
    // Probar la función directamente
    console.log('🧪 Probando crear usuario directamente en SQL...')
    const bcrypt = await import('bcrypt')
    const testPassword = await bcrypt.hash('test123456', 10)
    
    try {
      const testResult = await client.query(`
        SELECT * FROM fun_create_user(
          $1::VARCHAR(320),
          $2::VARCHAR(60),
          $3::VARCHAR(100),
          NULL
        )
      `, ['test' + Date.now() + '@test.com', testPassword, 'Test User'])
      
      console.log('✅ Usuario de prueba creado:')
      console.log(testResult.rows[0])
      
      // Limpiar usuario de prueba
      await client.query('DELETE FROM tab_users WHERE email LIKE $1', ['test%@test.com'])
      console.log('🗑️  Usuario de prueba eliminado')
      
    } catch (testError) {
      console.error('❌ Error al probar función:')
      console.error('   Mensaje:', testError.message)
      console.error('   Detalle:', testError.detail)
      console.error('   Hint:', testError.hint)
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message)
  } finally {
    client.release()
    await pool.end()
  }
}

checkFunction()
